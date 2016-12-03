---
title: "Final fields"
Tags: ["java", "jvm", "basics"]
Categories: ["Java"]
description: "What's up with final fields"
date: "2016-12-03"
---

##### Private final field modification
Yes it is possible and it doesn't require a lot of work. Since you should not 
use this mechanism in real life there are cases when it is useful. For 
example how is hibernate using this to hydrate final entity fields.

But when using final fields with hibernate you should be extra careful how you declare them.

<!--more-->

##### How to change final field
First things first. To change value of final field all you need to do:
```java
Field finalField = Whatever.class.getDeclaredField("fieldName");
finalField.setAccessible(true)
```
and you are good to go. From now on your final field will be modifiable.
 
But since it's not something you should do you might expect weird behaviour.
It's not normal to declare something final and expect it to be modified
(we are talking about reference change here).

There is this funny thing called compile time constants. Long story short javac will 
decide if field value is known in compile time and if it is then it's compile time constant. 
When constant is a compile time constant then javac will run another optimization called constant 
inlinig. This one is dangerous and might produce unexpected results.

##### Quick look at the bytecode

With simple java class:
```java
public class ByteCodeTest {
	private Long number = 10L;
	private final String inlined = "String to be inlined";

	public String getInlined() {
		return inlined;
	}

	public Long getNumber() {
		return number;
	}
}
```
you can run javap -c ByteCodeTest.class and we will see:
```
Compiled from "ByteCodeTest.java"
public class com.pchudzik.blog.immutable.ByteCodeTest {
  public com.pchudzik.blog.immutable.ByteCodeTest();
    Code:
       0: aload_0
       1: invokespecial #1                  // Method java/lang/Object."<init>":()V
       4: aload_0
       5: ldc2_w        #2                  // long 10l
       8: invokestatic  #4                  // Method java/lang/Long.valueOf:(J)Ljava/lang/Long;
      11: putfield      #5                  // Field number:Ljava/lang/Long;
      14: aload_0
      15: ldc           #6                  // String String to be inlined
      17: putfield      #7                  // Field inlined:Ljava/lang/String;
      20: return

  public java.lang.String getInlined();
    Code:
       0: ldc           #6                  // String String to be inlined
       2: areturn

  public java.lang.Long getNumber();
    Code:
       0: aload_0
       1: getfield      #5                  // Field number:Ljava/lang/Long;
       4: areturn
}
```
I've no idea how to read bytecod but using this [keywords reference](https://en.wikipedia.org/wiki/Java_bytecode_instruction_listings).
We can try to figure out some things. First Take a look at getInlined method. It will load constant from constant pool and 
will return reference to it. Things looks different for Long object. First object reference will be loaded, then field
will be read from object and finally it will be returned. See the diference? getInlined will not load object reference 
it will use variable directly from constant pool. 

You might ask what's the difference between String and Long? Long is an object. 10L is not it's primitive value 
and it must be converted to Long (Object). Autoboxing feature will kick in and will convert primitive 10L value to
Long object that's why it is not compile time constant.

##### Example

Since we know how it looks internally now we can trace how it works:
```java
static class ImmutableObject {
	private final String stringField = "can't touch this";
	private final Long longObjectField = 10L;
	private final long primitiveLong = 20L;

	public Long getLongObjectField() {
		return longObjectField;
	}

	public String getStringField() {
		return stringField;
	}

	public long getPrimitiveLong() {
		return primitiveLong;
	}

	@Override
	public String toString() {
		return "string=" + stringField + ",longObjectField=" + longObjectField + ",primitiveLong=" + primitiveLong;
	}
}
```

And quick look on how we can change final fields:
```java
final ImmutableObject object = new ImmutableObject();

final Field stringField = ImmutableObject.class.getDeclaredField("stringField");
final Field longObjectField = ImmutableObject.class.getDeclaredField("longObjectField");
final Field primitiveLongField = ImmutableObject.class.getDeclaredField("primitiveLong");

asList(stringField, longObjectField, primitiveLongField).forEach(f -> f.setAccessible(true));

stringField.set(object, "Yes I can");
longObjectField.set(object, 11L);
primitiveLongField.set(object, 21L);

System.out.println("field access");
System.out.println("string         = " + stringField.get(object));
System.out.println("long object    = " + longObjectField.get(object));
System.out.println("primitive long = " + primitiveLongField.get(object));

System.out.println("getters:");
System.out.println("toString       = " + object.toString());
System.out.println("string         = " + object.getStringField());
System.out.println("long object    = " + object.getLongObjectField());
System.out.println("primitive long = " + object.getPrimitiveLong());
```

The output is following:
```
field access
string         = Yes I can
long object    = 11
primitive long = 21
getters:
toString       = string=can't touch this,longObjectField=11,primitiveLong=20
string         = can't touch this
long object    = 11
primitive long = 20
```
So we can change values of final fields, but not really? No, the answer is inlining.
(I can not use fields directly because "Can't touch this" will be inlined in println as well")
But you can debug this and if you check value of the field it will be "Yes I can".

But long object works. Getter displays value properly. It's because of primitives auto boxing feature.
Note that value 10L is primitive so to make it work it must be boxed to Object Long since it's the type I want to use. 

Stepping on this mine is highly unlikely but nevertheless it's good to know and be aware
of things that are happening inside jvm. 

Source code of examples can be found on [github](https://github.com/pchudzik/blog-example-final-fields).
