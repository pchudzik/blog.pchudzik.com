---
title: "Immutable dto in jackson"
Tags: ["interesting"]
Categories: ["java"]
description: "How to create immutable dtos and deserialize them with jackson"
date: "2017-04-15"
---


Immutability and functional programming are hot right now. But how to achieve immutability with
objects deserialized from json? Luckily there is pretty old feature introduced in [jackson
2.7.0](https://github.com/FasterXML/jackson-databind/blob/master/release-notes/VERSION) which uses
constructor based object creation and uses
[@ConstructorProperties](https://docs.oracle.com/javase/7/docs/api/java/beans/ConstructorProperties.html)
(introduced in java7).

<!--more-->

With this approach you can easily deserialize immutable objects from json.

{{<highlight java>}}
import java.beans.ConstructorProperties;
import com.fasterxml.jackson.annotation.JsonAutoDetect;

// instead of JsonAutoDetect you can generate getters. It's required for serialization
@JsonAutoDetect(fieldVisibility = JsonAutoDetect.Visibility.ANY)
public class PointVanillaJava {
  private final int x;
  private final int y;

  @ConstructorProperties({"x", "y"})
  public PointVanillaJava(int x, int y) {
    this.x = x;
    this.y = y;
  }
}
{{</highlight>}}

Now jackson will be able to create object instance using properly annotated constructor. It's all
good but it is very verbose code. We can use lombok which has
[@RequiredArgsConstructor](https://projectlombok.org/features/Constructor.html) and it adds
@ConstructorProperties annotation to generated code automatically. With this in mind we can use
lombok to generate boring stuff:

{{<highlight java>}}
import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public class PointLombok {
  private final int x;
  private final int y;
}
{{</highlight>}}

Looks good just let's make sure everything works as expected:

{{<highlight groovy>}}
@Unroll
def "should deserialize point #pointClass.simpleName from json"() {
  when:
  final point = objectMapper.readerFor(pointClass).readValue("""{"x": 10, "y":20}""")

  then:
  point.x == 10
  point.y == 20

  where:
    pointClass << [
      PointLombok.class,
      PointVanillaJava.class
    ]
}
{{</highlight>}}

When I first saw when immutable entity with @RequiredArgsConstructor is properly deserialized from
json I was really surprised and had one of those wtf moments "how it's working? how is it working?"
Then I setup few brakpoints and finally figured out what's going on and how it's working :)

[source code](https://github.com/pchudzik/blog-example-immutable-dto)
