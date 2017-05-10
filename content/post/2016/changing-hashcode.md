---
title: "Consistent return of hashCode in java"
Tags: ["java", "hashCode", "equals", "basics"]
Categories: ["Java"]
description: "Hash code and equals and why you should avoid overwrite of it"
date: "2016-10-19"
---

HashCode and equals implementations are hard. Usually it's tricky to properly implement hashCode and
equals method to fully fulfill contract from java documentation. I'm going to focus on just one
point from the [hashCode
contract](https://docs.oracle.com/javase/8/docs/api/java/lang/Object.html#hashCode--):

> whenever it is invoked on the same object more than once during an 
> execution of a Java application, the hashCode method must consistently 
> return the same integer.

Read it already? Do it again. Let it sink and think about impact of "hashCode method must
consistently return the same integer"

<!--more-->

# TL;DR

Do not implement equals and hashCode unless you are 100% sure that you know what you are doing, what
is the impact of hashCode and equals contract and that it is absolutely required in your application
to have equals and hashCode implementation.


# Intro

If your equals and hashCode implementation looks like alt + insert (intellij) and generate equals
and hashCode or you are a "pro" and go with
[lombok](https://projectlombok.org/features/EqualsAndHashCode.html) or
[HashCodeBuilder](https://commons.apache.org/proper/commons-lang/javadocs/api-release/org/apache/commons/lang3/builder/HashCodeBuilder.html)
or any other tool which generates equals and hashCode for you. You should stop and think what you
are doing and what is the impact of invalid hashCode and equals implementation.

Just to remind you for what equals and hashCode exists: "This method is supported for the benefit of
hash tables such as those provided by HashMap." That's all. hashCode is used only in hash*
collections nothing more Of course you should implement hashCode when you implement equals because
equal objects must have equal hash codes.

That said let me demonstrate why it is important to carefully read contract you are signing by
implementation hashCode and equals. You can find all code samples on
[github](https://github.com/pchudzik/changing-hashcode).


# Code!

Consider following sample class:

```java
package com.pchudzik.hashcode;

import java.util.Objects;

class InconsistentHashCode {
  public String name;
  public int age;

  @Override
  public boolean equals(Object o) {
    if (this == o) {
      return true;
    }

    if (o == null || getClass() != o.getClass()) {
      return false;
    }

    InconsistentHashCode that = (InconsistentHashCode) o;
    return Objects.equals(name, that.name) && Objects.equals(age, that.age);
  }

  @Override
  public int hashCode() {
    return Objects.hash(name, age);
  }
}
```

Pretty obvious implementation I'm sure everybody did at least once. At first equals and hashCode
contract requirements are fulfilled but what about the one in hashCode: ```Whenever it is invoked on
the same object more than once during an execution of a Java application, the hashCode method must
consistently return the same integer```
 
What can happen if I ignore this requirement? let's check it:

```java
def "hashCode value should be consistent during execution of application set.contains example"() {
  given:
  final hashCode = new InconsistentHashCode(name: "John", age: 21)

  and:
  final set = new HashSet([hashCode])

  when:
  hashCode.age = 42

  then:
  set.contains(hashCode)
}
```

Test failure:

```
Condition not satisfied:

set.contains(hashCode)
|   |        |
|   false    com.pchudzik.hashcode.InconsistentHashCode@446d820
[com.pchudzik.hashcode.InconsistentHashCode@446d820]
```

Ok then. What else can happen if I implement hashCode incorrectly?

```java
def "hashCode value should be consistent during execution of application set.add example"() {
  given:
  final hashCode = new InconsistentHashCode(name: "John", age: 21)

  and:
  final set = new HashSet([hashCode])

  when:
  hashCode.age = 42

  then:
  set.add(hashCode) == false
}
```

and result:

```
Condition not satisfied:

set.add(hashCode) == false
|   |   |         |
|   true|         false
|       com.pchudzik.hashcode.InconsistentHashCode@446d820
[com.pchudzik.hashcode.InconsistentHashCode@446d820, com.pchudzik.hashcode.InconsistentHashCode@446d820]
```

The further it goes the more interesting it gets:

```java
def "hashCode value should be consistent during execution of application set.size example"() {
  given:
  final hashCode = new InconsistentHashCode(name: "John", age: 21)

  and:
  final set = new HashSet([hashCode])

  when:
  hashCode.age = 42

  and:
  set.add(hashCode)

  then:
  set.size() == 1
}
```

and it fails miserably:

```
Condition not satisfied:

set.size() == 1
|   |      |
|   2      false
[com.pchudzik.hashcode.InconsistentHashCode@446d820, com.pchudzik.hashcode.InconsistentHashCode@446d820]
```

If you think about it all makes sense, the problem is we rarely think about real impact of hashCode
implementation especially when new hot features are expected to be delivered asap.

Usually applications are not that simple. There are a lot of frameworks utilities, helpers and other
libraries. There are alse libraries which will [generate
hashCode](https://projectlombok.org/features/EqualsAndHashCode.html) for you. I'm not saying that
you should not use them, those libraries are great time savers and you should use them. Just think
before you use them and consider impact of this autogenerated stuff and if you can live with it.

# What should I do?

The simplest advice is do not implement hashCode and equals at all. Seriously in most cases you are
good to go without equals and hashCode and everything will work exactly as expected. Hibernate will
also manage without equals and hashCode. So why bother. Let JVM do it's thing and don't worry.

If you are really really sure that hashCode and equals are must have for you then there are
options...

If you have final fields that are good for hashCode then you are not doomed. Use them for hashCode
and provide equals method which will compare your objects properly and you should be good to go.
Just remember that hashCode values should have big dispersion to optimize hash* collections. So
using enum with two possible values might not be good idea after all...
