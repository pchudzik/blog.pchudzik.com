---
title: "Test methods coupling"
Tags: ["tdd", "basics"]
Categories: ["java"]
description: "Why test methods coupling is an anti pattern"
date: "2016-10-29"
---

Sometimes when unit tests setup is complex we are tempted to take shortcuts and write single setup
for all tests which will save as few keystrokes. In the time of writing the test it might feel like
good idea to configure complex unit test setup and reuse it in all test. This way we avoid code
duplication and we create more condensed test.

This approach looks good only in the time of the writing tests. Then there is a time when unit tests
must be maintained. This is the time when you usually realise that saving few keystrokes wasn’t such
a good idea.

<!--more-->

# TL;DR;

Good tests are not coupled and do not have shared state. Shared state in unit tests makes each test
method tightly coupled with all tests methods in the unit this makes understanding and maintenance
of unit tests very hard.

# Code!

[Code samples](https://github.com/pchudzik/blog-example-test-coupling)

Product class:

```java
@RequiredArgsConstructor
class Product {
  private final String name;
  private final Set<Category> categories = new HashSet<>();
  private final Set<Tag> tags = new HashSet<>();

  public void addProductCategory(Category category) { /* ... */ }

  private boolean categoryIsAlreadyAssigned(Category category) { /*...*/ }

  public void removeProductCategory(Category category) { /*...*/ }

  public void removeTag(Tag tag) { /*...*/ }

  public void addTag(Tag tag) { /*...*/ }

  public Set<Tag> getTags() { /*...*/ }

  public Set<Tag> getPossibleTags() { /*...*/ }
}
```

Two additional which will simulate test object setup complexity:

```java
class Category {
  private String name;

  private Category parentCategory;
  private List<Category> childCategories = new LinkedList<>();

  private Set<Tag> tags = new HashSet<>();
}

@Data
class Tag {
  private String name;
}
```

I’m going to focus on implementation of Product class which can be assigned to single category
inside tree branch. Product can be assigned to multiple categories in different tree branches. Tags
from selected categories can be assigned to product.


Let’s write some tests to make sure our code works. But do I really need to create all the
categories for all the tests? Since each test setup is basically the same. Create product, do stuff
with categories on product, verify behaviour. So let’s start by creating category tree:

```java
def rootCategory1TagA = new Tag(name: "A")
def rootCategory1TagB = new Tag(name: "B")
def rootCategory2TagC = new Tag(name: "C")
def child1TagD = new Tag(name: "D")
def child1TagE = new Tag(name: "E")
def child2TagF = new Tag(name: "F")
def otherChildTagG = new Tag(name: "G")

def rootCategory1 = new Category(
    name: "root1", 
    tags: [rootCategory1TagA, rootCategory1TagB])
def rootCategory2 = new Category(
    name: "root2", 
    tags: [rootCategory2TagC])
def child1OfRootCategory1 = new Category(
    name: "child 1 of root1", 
    parentCategory: rootCategory1, tags: [child1TagD, child1TagE])
def child2OfRootCategory1 = new Category(
    name: "child 2 of root1", 
    parentCategory: rootCategory1, tags: [child2TagF])
def otherChildOfRootCategory2 = new Category(
    name: "other child", parentCategory: 
    rootCategory2, tags: [otherChildTagG])
        
rootCategory1.childCategories.addAll([child1OfRootCategory1, child2OfRootCategory1])
rootCategory2.childCategories.addAll(otherChildOfRootCategory2)
```

When tree and tags are ready we can write some tests:
```java
def "product can be assign to only one category in category tree branch"() {
  given:
  final product = new Product("product")
  product.addProductCategory(child2OfRootCategory1)

  when:
  product.addProductCategory(rootCategory1)

  then:
  thrown(IllegalStateException)
}

def "should remove all tags from product related to removed category"() {
  given:
  final product = new Product("product")
  product.addProductCategory(child1OfRootCategory1)
  product.addProductCategory(otherChildOfRootCategory2)
  (child1OfRootCategory1.tags + otherChildOfRootCategory2.tags).each { product.addTag(it) }

  when:
  product.removeProductCategory(child1OfRootCategory1)

  then:
  product.tags == [otherChildTagG] as Set
}

def "should reject tag assignment not related to product category"() {
  given:
  final product = new Product("product")

  when:
  product.addTag(otherChildTagG)

  then:
  thrown(IllegalStateException)
}

def "should find all possible product tags"() {
  given:
  final product = new Product("product")
  product.addProductCategory(child1OfRootCategory1)
  product.addProductCategory(otherChildOfRootCategory2)

  expect:
  product.possibleTags == [child1TagD, child1TagE, otherChildTagG] as Set
}

def "should exclude already assigned tag from possible tags"() {
  given:
  final product = new Product("product")
  product.addProductCategory(child1OfRootCategory1)
  product.addTag(child1TagD)

  expect:
  product.possibleTags == [child1TagE] as Set
}
```

All good? No, not really. If you’ve actually read test code you probably jumped back and forward few
times to find out what is the real test setup and how the category tree looks like in order to
understand test. It gets even worse with time.

* After 4 months there is change request: “Product can be assigned to any category in the tree.
 Because system moderator should be responsible for product placement inside category tree”
* There is a bug in category assignment error detection. Assign product to category “child”. Then
 assign product to category “parent”. Expected error. Actual assignment is possible.
* New team member is wondering how tag’s autocomplete box is constructed for the product.

In case of change request test setup might become obsolete. We might no longer need complex tree to
verify category assignment rules. Question is will you read all the tests to verify if tests setup
can be actually modified?

In case of the bug we must step carefully because of the complex test setup it will be easy to break
other tests. Making changes in tests setup might break other test cases. Making them fail is not as
bed as making them permanently green.

When new colleague checks how tags selection works he must jump back and forward to find how
category tree works, which tags are assigned to which category. Reading tests like this usually
result in debugging session with live application because it’s easier to start application and hit
F8 few times just to make sure everything works as you’d expect it to work.

# Solution 

The solution is simple. Avoid tests coupling. In this case it’s easy because test setup is not that
complex, but there are other ways which will help to create lousy coupled tests.


There are options to make complex test setup without shared state.

Test object factories. When object creation is complicated, and objects required to verify test
subject are complex by themselves than responsibility of simplifying object creation can be
delegated to test factories:
 
```java
createCategoryWithChildren(“category”, [anyCategory(“child1”), [anyCategory(“child2”)].
```

This way you work with real objects, complex object creation is hidden in other class. What’s more
test factory might hide implementation changes from other tests (for example constructor change, or
implementation details which will affect the way object must be created).

Another solution is to use mocks. If you do not care about complexity of test helper objects setup,
and you are not really interested in the way additional objects works, and your test subject is just
holder of those additional entities then mocks are fine.


Without tightly coupled tests refactoring is easy because you are just working one case at the time.
Bug fixing is easy - all you need is to understand the bug, you don’t need to understand test setup.
Tests are easy to read and understand, each test case is independent unit and you can focus on small
part of the system. Because test case is not bloated with additional stuff not related to this
particular test it is usually very condensed and contains only what is necessary to make sure code
works.

<small> When I was preparing code samples I noticed something I haven’t spotted earlier (maybe
because I always try to avoid shared tests state, and it was really weird doing it) when following
TDD it’s actually easier to write better tests because you don’t know yet how implementation will
look so it’s very hard to make assumptions on how to setup all the tests. When you go and write
production code first and then add tests it’s tempting to create single test setup method which will
prepare ground for all the cases you can came up with just after you’ve just finished
implementation. </small>
