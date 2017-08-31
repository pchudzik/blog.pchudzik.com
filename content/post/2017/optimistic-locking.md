---
title: "Optimistic locking pitfalls"
Tags: ["basics", "hibernate"]
Categories: ["java"]
description: "Optimistic locking pitfalls"
date: "2017-04-27"
---

Optimistic locking is concurrency control method that allows to execute multiple transactions
simultaneously as long as they don't interfere which each other. That's definition from
[wikipedia](https://en.wikipedia.org/wiki/Optimistic_concurrency_control). You probably already know
that [Hibernate supports optimistic locking](
http://docs.jboss.org/hibernate/orm/5.2/userguide/html_single/Hibernate_User_Guide.html#locking) and
all you have to do in order to implement optimistic locking in you app is to add @Version on number
or timestamp field and you are good to go. Right?

<!--more-->

# tl;dr

If you care about data consistency and user experience you should take advantage of optimistic
locking feature built in JPA and in order to do so sometimes you have to write some additional code.

# Intro

We will do classic [Alice and Bob](https://en.wikipedia.org/wiki/Alice_and_Bob) example:

![Multiple users working with the same content](/post/2017/optimistic-locking/optimistic-locking.png)

Bob starts writing a post and when the first version is ready he clicks save button. Alice notices
new post and decides to fix paragraphs order. In the meantime, Bob is still working on his post
version fixing typos etc. What will happen when Bob decides to save his post version is not really
important. Important is that it should not be accidental behavior but a deliberate action.

# Plain SQL

Let's start with plain SQL example of optimistic locking. Optimistic locking is very useful in
update queries:

{{<highlight sql>}}
update post
set
  title = 'new title',
  content = 'new content'
where
  id = 1
{{</highlight>}}

In the above example an object can be updated anytime query is executed. It doesn't matter if the
post has changed five times already. Title and content will be updated. When Bob starts post edition
in the morning and then decides to save it after lunch it will overwrite all changes made by Alice.
This might not be expected behavior. Usually we want to make sure that users will not overwrite
other people's work:


{{<highlight sql>}}
update post
set
  title = 'new title',
  content = 'new content',
  version = 2
where
  id = 1
  and version = 1
{{</highlight>}}

Now when Bob saves his post version after lunch nothing is changed because Alice updated post in the
meantime and Bob's query will not match any records.

# JPA

We rarely rely on plain SQL when writing java applications. Approach we often use in applications is
to add number or timestamp field annotated with @Version and leave rest of the work to the JPA
implementation.
 
Think what's really going on. Your transaction is running for about 100 - 300ms and Hibernate will
keep updating version to make sure optimistic locking is in place every time transaction is
committed. When your data is mostly read what are the chances that two users will click save button
at the exact same moment (when we talk about production server then it will be next Friday at
5pm...)? When data gets back from the UI you probably just do entityManager.load(id) and then do
some stuff with it. Data was on UI for some time, how to do you know it is up to date and if there
was no modification in the meantime? If you are not using version field and don't send it to the
client (there are other use cases and solutions but we are talking about simple forms, not those
fancy text editors designed for collaboration) you'll overwrite those changes. The point is:
optimistic locking can't help you if you are not using it.

Let's write some code to see what's going on and why version must be used properly to work as
expected. First, take a look at the model:

{{<highlight java>}}
@Entity
@Getter
@NoArgsConstructor(access = AccessLevel.PRIVATE)
public class Post {
  @Id
  @GeneratedValue
  private Long id;

  @Version
  private Long version;

  private String title;
  private String content;

  public Post(String title, String content) {
    this.title = title;
    this.content = content;
  }

  public void update(String newTitle, String newContent) {
    this.title = newTitle;
    this.content = newContent;
  }
}
{{</highlight>}}

Our entity is very simple and we can send entity directly to the client:

{{<highlight groovy>}}
def "working optimistic locking when using entityManager.merge"() {
  given: "Bob saves first post version"
  final firstPostVersion = transactionTemplate.execute({ status ->
    entityManager.merge(new Post("post", "content"))
  })

  when: "Alice changes paragraphs order while Bob is fixing typos"
  transactionTemplate.execute({ status ->
    entityManager
      .find(Post.class, firstPostVersion.id)
      .update("Alice's title", "Alice's content")
  })

  and: "Bob fixed some typos in first version"
  transactionTemplate.execute({ status ->
    entityManager
      .merge(firstPostVersion)
      .update("Bob's title", "Bob's content")
  })

  then: "conflict is expected because Alice updated post while Bob was editing it"
  thrown OptimisticLockException
}
{{</highlight>}}

As you can see in then block hibernate handlers optimistic locking properly and will throw
javax.persistence.OptimisticLockException when we try to save outdated entity. It is still your job
to handle it and notify Bob that Alice updated his post, but he is aware of that and he can decide
what do to with Alice's version.

Sending whole entity to the client is not always an option (DDD with complicated aggregate root or
performance issues or whatever). Luckily there is ready to use pattern [Data Transfer
Object](https://en.wikipedia.org/wiki/Data_transfer_object).

Sending DTOs to the client might be tricky because it is your responsibility to handle versioning
properly. If you skip version field in your DTO you might end up with users overwriting each other
work:

{{<highlight java>}}
@Data
class PostDtoWithoutVersion {
  private final Long id;
  private String title;
  private String content;
}
{{</highlight>}}

And simple test proving the point:

{{<highlight groovy>}}
def "optimistic locking failure without sending version to the client"() {
  given: "Bob saves first post version"
  final postId = transactionTemplate.execute({ status ->
    entityManager.merge(new Post("post", "content"))
  }).id

  when: "Alice changes paragraphs order while Bob is fixing typos"
  final alicePostDto = transactionTemplate.execute({ status -> 
    new PostDtoWithoutVersion(entityManager.find(Post.class, postId)) 
  })
  alicePostDto.title = "Alice's title"
  alicePostDto.content = "Alice's content"


  and: "Bob is fixing typos in first version"
  final bobPostDto = transactionTemplate.execute({ status -> 
    new PostDtoWithoutVersion(entityManager.find(Post.class, postId)) 
  })
  bobPostDto.title = "Bob's title"
  bobPostDto.content = "Bob's content"

  and: "Alice clicks save"
  transactionTemplate.execute({ status ->
    entityManager
      .find(Post.class, alicePostDto.id)
      .update(alicePostDto.title, alicePostDto.content)
  })

  and: "Bob clicks save"
  transactionTemplate.execute({ status ->
    entityManager
      .find(Post.class, bobPostDto.id)
      .update(bobPostDto.title, bobPostDto.content)
  })

  then: "database state when Alice and Bob are finished with post edition"
  final postInDb = transactionTemplate.execute({ status -> 
    entityManager.find(Post.class, postId) 
  })
  postInDb.title == "Bob's title"
  postInDb.content == "Bob's content"
}
{{</highlight>}}

In the above example Hibernate has no idea what is going on and it can not help you with optimistic
locking. We just tell it to load the latest version from DB apply changes on it and persist it.
Without proper version control Bob will overwrite all changes made by Alice.

To avoid this issue we can simply send version to the client:

{{<highlight java>}}
@Data
public class PostDto {
  private final Long id;
  private final Long version;
  private String title;
  private String content;
}
{{</highlight>}}

And everything will work like in the first test case:

{{<highlight groovy>}}
def "working optimistic locking when sending version to the client"() {
  given: "Bob saves first post version"
  final Post firstPostVersion = transactionTemplate.execute({ status ->
    entityManager.merge(new Post("post", "content"))
  })

  when: "Alice changes paragraphs order while Bob is fixing typos"
  final PostDto alicePostDto = transactionTemplate.execute({ status -> 
    new PostDto(entityManager.find(Post.class, firstPostVersion.getId())) 
  })
  alicePostDto.title = "Alice's title"
  alicePostDto.content = "Alice's content"


  and: "Bob is fixing typos in first version"
  final PostDto bobPost = transactionTemplate.execute({ status -> 
    new PostDto(entityManager.find(Post.class, firstPostVersion.getId())) 
  })
  bobPost.title = "Bob's title"
  bobPost.content = "Bob's content"

  and: "Alice clicks save"
  transactionTemplate.execute({ status ->
    findPost(alicePostDto.id, alicePostDto.version)
      .update(alicePostDto.title, alicePostDto.content)
  })

  and: "Bob clicks save"
  transactionTemplate.execute({ status ->
    findPost(bobPost.id, bobPost.version)
      .update(bobPost.title, bobPost.content)
  })

  then:
  thrown OptimisticLockException
}
{{</highlight>}}

Additional method is required which will make sure we are working with proper post version:

{{<highlight java>}}
private Post findPost(Long id, Long version) {
  final post = entityManager.find(Post.class, id)
  if (post.version != version) {
    throw new OptimisticLockException()
  }
  return post
}
{{</highlight>}}

Fetching whole entity just to check version might not be the best idea, but it works for our
example. In real world, DB should do version checking for you (from Post where id = :id and version
= :version) and it will be your job to handle the situation when nothing is found.


# Summary

Optimistic locking will not be magically handled by Hibernate if it doesn't know what's going on.
When it is required it is important to make sure that everything works as we want it to work and not
by accident. Tracking versions is not always necessary (for example when you have _one_ admin user)
but it is important to find out places where multiple users can work with the same object and make
sure application is handling conflicts properly.

<small>[source code](https://github.com/pchudzik/blog-example-jpa-versioning)</small>
