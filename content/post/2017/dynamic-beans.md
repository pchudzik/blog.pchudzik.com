---
title: "Dynamic beans in spring"
Tags: ["spring", "howto"]
Categories: ["java"]
description: "How to create dynamic beans in spring framework"
date: "2017-05-31"
---

Some time ago I've been trying to dynamically create spring beans. After fast stackoverflow check I
decided to drop it and go with something else. Lately I've been trying to implement more complicated
bean registration mechanism in which skipping dynamic bean creation wasn't an option. Here's how
you can create spring beans "from code".

<!--more-->

# tl;dr

* make sure you absolutely need it
* implement [BeanFactoryPostProcessor](http://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/beans/factory/config/BeanFactoryPostProcessor.html)
* create [BeanDefinition](http://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/beans/factory/config/BeanDefinition.html)
* add BeanDefinition to [BeanDefinitionRegistry](http://docs.spring.io/spring/docs/current/javadoc-api/org/springframework/beans/factory/support/BeanDefinitionRegistry.html)

# Creating single bean

Not sure why you might be interested in this since you can just annotate your class with @Component
annotation but let's start from it.

```java
@RequiredArgsConstructor
class DynamicBeanExample {
  private final String beanId;
  private final TestDependency testDependency;
}

@Component
class SingleDynamicBeanProcessor implements BeanFactoryPostProcessor {
  @Override
  public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
    final BeanDefinitionRegistry beanDefinitionRegistry = (BeanDefinitionRegistry) beanFactory;
    final BeanDefinition dynamicBean = BeanDefinitionBuilder
        .rootBeanDefinition(DynamicBeanExample.class)
        .setScope(SCOPE_PROTOTYPE)
        .addConstructorArgValue("dynamically created bean")
        .getBeanDefinition();

    beanDefinitionRegistry.registerBeanDefinition("dynamicBean", dynamicBean);
  }
}
```

You can define scope, add constructor arguments, inject other beans, and set name of the bean.

Note that DynamicBeanExample has constructor with two arguments. First one is string, second is
TestDependency object. You can skip this kind of dependency and spring will automatically provide
bean instance.

# Creating multiple dynamically defined beans

Creating single bean instance was easy. Creating multiple instances of the same bean is just putting
bean creation in the loop ;) But let's complicate it a bit and use factory method instead:

```java
@Component
class DynamicBeanFactoryProcessor implements BeanFactoryPostProcessor {
  @Override
  public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
    final BeanDefinitionRegistry beanDefinitionRegistry = (BeanDefinitionRegistry) beanFactory;

    IntStream
        .range(0, 100)
        .forEach(index -> beanDefinitionRegistry.registerBeanDefinition("repeatableBean" + index, BeanDefinitionBuilder
            .rootBeanDefinition(DynamicBeanExample.class)
            .setFactoryMethodOnBean("createInstance", "dynamicBeanFactoryProcessor")
            .addConstructorArgValue("repeatable bean " + index)
            .addConstructorArgReference("testDependency")
            .getBeanDefinition()));
  }

  DynamicBeanExample createInstance(String beanId, TestDependency testDependency) {
    return new DynamicBeanExample(beanId, testDependency);
  }
}
```

It works almost the same as constructor based initialization. You just pass arguments to factory
method not constructor itself. This alone allows to do a lot of "interesting" things...

# My original issue

Long story short I needed to create unknown number of beans based on some options defined in
properties. It was more complicated and that's why I wasn't able to just provide external xml
configuration and import it into my application context but let's keep it simple to show clear
example on how to implement it.

Unfortunately you don't have access to spring magic from BeanFactoryPostProcessor - no properties,
no environment, no beans. Only definitions of the objects that will be created by container later so
you need to do some work by yourself but with below example I'm sure you will be able to do whatever
you want.

```java
@Component
class ConfigurableBeanFactory implements BeanFactoryPostProcessor, InitializingBean {
  private List<String> beanInstances;

  @Override
  public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
    final BeanDefinitionRegistry registry = (BeanDefinitionRegistry) beanFactory;
    beanInstances.forEach(instance -> {
      registry.registerBeanDefinition(instance, BeanDefinitionBuilder
          .rootBeanDefinition(TestRepository.class)
          .addConstructorArgValue(instance)
          .getBeanDefinition());
    });
  }

  @Override
  public void afterPropertiesSet() throws Exception {
    this.beanInstances = asList(PropertiesLoaderUtils
        .loadProperties(new ClassPathResource("/application.properties"))
        .getProperty("dynamic-beans.instances", "")
        .split(","));
  }
}
```

First of all we are loading properties file. Loading it from application.properties doesn't make a
lot of sense but it is just an example. You can load this from file, system properties, environment
variables or do whatever you want like load something (even class) from network resource etc.

For each loaded property create bean definition and you are good to go.

# Summary

It turns out that programmatically created beans are easy to implement. It is worth pointing out
that this way you can create much more complicated structures. With BeanFactoryPostProcessor you can
do a lot of scary stuff so remember that with great power comes great responsibility.

<small>[samples](https://github.com/pchudzik/blog-example-dynamic-beans)</small>