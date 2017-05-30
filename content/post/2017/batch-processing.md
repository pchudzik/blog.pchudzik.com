---
title: "Poor man's batch processing in JPA"
Tags: ["spring", "hibernate"]
Categories: ["java"]
description: "Batch processing using jpa"
date: "2017-05-16"
---

Working with a lot of data using plain JPA or hibernate or spring-data is possible, it does work and
usually it doesn't require a lot of extra codding. Starting small is the fastest way of getting
things done but you must be aware of few things that might shoot you in the foot.

<!--more-->

# tl;dr

* control session cache size. Call
   [flush()](http://docs.oracle.com/javaee/7/api/javax/persistence/EntityManager.html#flush--) and
   [clear()](http://docs.oracle.com/javaee/7/api/javax/persistence/EntityManager.html#clear--)
   regularly to reduce memory and time usage
* control transaction size 
* figure out deterministic way of fetching data 
* don't be afraid to remove guerilla solution and commit to framework/library designed for the job

# In general

When working with big chunks of data it's important to control entity manager size and flush results
to the database regularly. Remember that entity manager should be flushed  and then cleared. Flush
doesn't clear session cache! If you don't clear
[entityManager](http://docs.oracle.com/javaee/7/api/javax/persistence/EntityManager.html) regularly
each entity you save (and flush) stays in entityManager and consumes RAM. What's more it's not only
about memory usage because you can always buy more RAM. Hibernate dirty checking will have to verify
all items in the session cache before flushing data to the DB. So first time it will check 100
entities, next time it will check 200, next there will be 300 and it will grow unless cache is
evicted. Working with big data loads in JPA/hibernate forces you to control some things and it's
your job to deallocate memory and think ahead.

Another important thing is transaction management. In case of very long running tasks you might want
to split single job across multiple transactions (for example one results page = one transaction).
If job is not required to be executed in single transaction you should split it into the smallest
possible units of work. There is nothing more annoying then transaction running for two hours and
failing because someone updated minor detail, which updated version field in the DB, which, caused
batch processing transaction to rollback... On one side of the coin it is good idea to keep
transaction as small as possible but on the other side executing a lot of small transactions might
be slower then few bigger ones. It is your decision and you should select transactions size just
right for your application.

The last thing is entities order. If your job is running for some time you should decide how to
handle new records or updated ones. Ids which are usually sequentially ascending numbers might be
good starting point for data sort (won't work with updates but it's a start). The general idea is to
have deterministic way of fetching data and strategy on how to handle updates and new entities. Last
time I was forced to do a bit of batch processing in plain JPA I've used simple last_updated_time
which was already there and was perfect for the job. In more complex situations in which you must
split your job across multiple transactions you might consider fetching list of all ids upfront.

Transaction management and cache size control are application specific but you should be aware of
them since the beginning because not thinking about it now might cost you a lot of time in the
future. Another thing worth pointing out is that you should always verify if your application works
fine with production like data. Writing some tests running on in memory db is convenient but without
load testing you will never be sure if you batch job will not fail after processing one million of
entities.

If your batch processing is getting complicated and you feel like there is more and more corner
cases you need to handle you should consider switching to something more sophisticated like
spring-batch.

# Example of data insert:

Data insert is very simple just remember about clearing entity manager and be aware of transaction
size which is ignored in this example ;) You can try and extract transactional methods which will
actually insert portions of the data (which will be ugly because
[@Transactional](https://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/transaction/annotation/Transactional.html)
requires public method) or fallback to plain
[TransactionTemplate](https://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/transaction/support/TransactionTemplate.html)
which will allow to hide some of the implementation details.

````java
@Component
@RequiredArgsConstructor
class DataInsert {
  private final EntityManager entityManager;
  
  public void insertProducts(Iterable<Product> products) {
    int batch = 0;

    for (Product product : products) {
      entityManager.persist(product);

      batch++;

      if (batch % 100 == 0) {
        flushAndClear();
      }
    }

    flushAndClear();
  }

  private void flushAndClear() {
    entityManager.flush();
    entityManager.clear();
  }
}
````

Note flush and clear (in that order, otherwise nothing will be persisted) executed once in awhile.


# Examples of data fetch

## Plain JPA

 ```java
@Component
@RequiredArgsConstructor
class JpaIterable implements Iterable<Product> {
  private final EntityManager entityManager;

  @Override
  public Iterator<Product> iterator() {
    return iterator(100);
  }
  
  public Iterator<Product> iterator(int batchSize) {
    return new ProductIterator(batchSize);
  }

  private class ProductIterator implements Iterator<Product> {
    private final int pageSize;

    private int firstResult = 0;
    private Iterator<Product> productsIterator;

    ProductIterator(int pageSize) {
      this.pageSize = pageSize;
    }

    @Override
    public boolean hasNext() {
      if(productsIterator == null || !productsIterator.hasNext()) {
        loadNextPage();
      }

      return productsIterator.hasNext();
    }

    @Override
    public Product next() {
      if(!hasNext()) {
        throw new NoSuchElementException("No more elements");
      }
      return productsIterator.next();
    }

    private void loadNextPage() {
      final List<Product> productsPage = entityManager
        .createQuery("from Product order by id", Product.class)
        .setFirstResult(firstResult)
        .setMaxResults(pageSize)
        .getResultList();

      firstResult += productsPage.size();
      productsIterator = productsPage.iterator();
    }
  }
}
```

We can create stupid simple iterator which is responsible for fetching next page when we've fetched
all data on current page. Above is not perfect implementation but will do for the simplest use
cases.

Note usage of iterator and iterable interfaces. Squeezing implementation details into standard is
usually good idea. In this case you can replace fetch implementation without affecting processing
logic. It is leaking because you need to remember about flush and clear, but it is still better then
exposing implementation to the outside. With java8 you should consider using stream, but you can
convert iterator to a stream at any time using
[StreamSupport](https://docs.oracle.com/javase/8/docs/api/java/util/stream/StreamSupport.html#stream-java.util.Spliterator-boolean-)
and
[Spliterator](https://docs.oracle.com/javase/8/docs/api/java/util/Spliterators.html#spliteratorUnknownSize-java.util.Iterator-int-)


## Hibernate

If you are using hibernate anyway and don't mind polluting your code with filthy implementation
details (;)) you can take advantage of
[ScrollableResult](http://docs.jboss.org/hibernate/orm/5.2/javadocs/org/hibernate/ScrollableResults.html)
which allows to do exactly the same we did in plain JPA.

```java
@Component
@RequiredArgsConstructor
class HibernateIterable implements Iterable<Product> {
  private final EntityManager entityManager;

  private class ProductIterator implements Iterator<Product>, Closeable {
    private final ScrollableResults scrollableResults;
  
    private Object[] nextRow;
  
    ProductIterator() {
      final Session session = entityManager.unwrap(Session.class);
    
      this.scrollableResults = session
        .createQuery("from Product order by id")
        .scroll(ScrollMode.FORWARD_ONLY);
    }
  
    @Override
    public boolean hasNext() {
      if (!hasNextRow()) {
        return goToNextRow();
      }
    
      return hasNextRow();
    }
  
    @Override
    public Product next() {
      if (!hasNext()) {
        throw new NoSuchElementException("No more results");
      }
    
      try { 
        return (Product) nextRow[0]; 
      } finally { 
        goToNextRow(); 
      }
    }
  
    @Override
    public void close() throws IOException {
      scrollableResults.close();
    }
  
    private boolean goToNextRow() {
      scrollableResults.next();
      nextRow = scrollableResults.get();
    
      return hasNextRow();
    }
  
    private boolean hasNextRow() {
      return nextRow != null;
    }
  }
}
```

Like in plain JPA example we still can squeeze and hide hibernate implementation in standard java
interfaces (note that it is more complicated than plain JPA, but it is still worth considering when
you decide to use
[StatelessSession](http://docs.jboss.org/hibernate/orm/5.2/javadocs/org/hibernate/StatelessSession.html)).
StatelessSession will detach any entity right after fetch (if it's what you want). It might come in
handy when all you need to do is read data.

When it comes to hibernate there are a lot configuration switches which will allow you to [control
things](https://docs.jboss.org/hibernate/orm/5.2/userguide/html_single/Hibernate_User_Guide.html#batch).

## spring-data

Spring data supports java8 streams so there is not much to there. Just create repository and make
sure you'll return stream of entities:

```java
interface SpringDataStream extends Repository<Product, Long> {
  @Query("from Product order by id")
  Stream<Product> findProducts();
}

```

From all of the above spring data saves us a lot of writing and testing, but sometimes it is good to
know what's going on under the hood.

# Data removal

I prefer to use plain sql/jpql/hql/whatever with where condition which will handle removal of
everything I want to remove. Two things that are important about data removal using sql. One is to
ensure that any pending entity manager state should be flushed before executing update. Second is
that you should clear session cache after updating statment (or just before it) because query was
executed directly on database and session cache might be not aligned with DB state after removal
operation.

If plain sql is not possible because some additional business logic must be executed when deletion
is performed then I'd approach in the same manner as update.

<small>[samples](https://github.com/pchudzik/blog-example-jpa-batch)</small>