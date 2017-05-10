---
title: "Java repositories testing"
Tags: ["java", "tdd", "spring-boot", "hibernate", "flyway"]
Categories: ["Java"]
description: "Sample on how to configure DB for tests"
date: "2016-11-06"
---

Few days ago I’ve stumbled upon sql query performance issue. Git claims that I was the author so
maybe that's the reason I remember this feature. There was like 3 classes, everything was super easy
and super fast all I needed to do was to let hibernate do it’s thing. Then time passed, new features
were requested, model become more complex, number of rows increased to ~4 millions and original
query became too slow.

When working on query optimisation I was really happy to find that detailed tests are in place. With
proper test setup I was able to test my new query to make sure all requirements are met and then
quickly copy paste query to sqldeveloper run it on test environment and verify if performance is
acceptable. It wasn't simple query and it took me some time to figure out how to make it quick and
work exactly as old one. That was the time I was really glad that we invested in detailed unit tests
in the beginning.

<!--more-->

# TL;DR
It’s possible to tests java repositories easily and you should do it.


# Details

Great presentation (polish) about database testing:

<iframe width="640" height="360" src="https://www.youtube.com/embed/8k_YpPVaIYA" frameborder="0" allowfullscreen></iframe>

Few key points from Piotr’s presentation:

* Do not touch production database (no inserts, updates etc).
* It’s ok to use h2 on developer machine (you can create workarounds for unsupported features)
* Your test database should be setup using production migration script (not hibernate's create-drop)
* Automate as much as possible (from CI env to production like database setup)
* Keep you migrations history straight (no out of order migrations)


I’d add few more points:

* Test your application against production database (it’s ok to use h2 on localhost, but CI must
 execute tests on production database)
* On test/integration env run your application with production like database state (everything will
 work fast with 10 records)
* Treat your repository layer like everything else. You are testing your business logic in domain or
 services for sure. Is there any reason why you should skip repositories layer?
* Make sure it’s easy to setup production like environment on localhost (docker, vagrant whatever
 the point is it should be possible, easy and fast)


# CODE!

Piotr in his presentation does not show a lot of code samples. In order to verify how this approach
works with spring-boot (which I avoid in complex applications) I decided to create very [simple
project](https://github.com/pchudzik/blog-example-database-testing) which will demonstrate how to
write tests for repository layer.

We are talking about spring-boot application with hibernate and flyway. The assumption is that
flyway is responsible for database setup on production, and since it's configuring DB on production
it will setup database for tests. I'm going to use two databases. PostgreSQL for production like
environment and H2 for local development. Tests and application will work on both databases.

Model will be very simple. Two classes:

```java
@Entity
@Table(name = "user_")
@ToString(exclude = {"password", "roles"})
public class User {
  @Id
  @GeneratedValue(strategy = GenerationType.SEQUENCE)
  private Long id;

  @Getter
  private String login;

  private String password;

  @ManyToMany
  private Set<Role> roles = new HashSet<>();
}

@Entity
public class Role {
  @Id
  @GeneratedValue(strategy = GenerationType.SEQUENCE)
  private Long id;

  private String name;
}
```

Two simple repositories:

```java
public interface RoleRepository extends JpaRepository<Role, Long> { }

public interface UserRepository extends JpaRepository<User, Long> {

  @Query("from #{#entityName} where lower(login) = lower(:login) and password = :password")
  User login(
    @Param("login") String login,
    @Param("password") String password);

  @Query("select case " +
         "  when count(u) > 0 then true " +
         "  else false " +
         "end " +
         "from #{#entityName} u " +
         "join u.roles roles " +
         "where " +
         "  u.login = :login " +
         "  and :role in(roles)")
  boolean userHasRole(
    @Param("login") String login,
    @Param("role") Role role);
}
```

Nothing interesting in RoleRepository and not much in UserRepository but complexity is not the point
here.

```java
class UserRepositoryTest extends RepositorySpecification {
  @Autowired
  UserRepository userRepository

  @Autowired
  RoleRepository roleRepository

  def "should login user by exact password match"() {
    given:
    final password = "pass"
    final user = userRepository.saveAndFlush(new User(login: "login", password: password))

    expect:
    userRepository.login(user.login, password).id == user.id

    and:
    userRepository.login(user.login, password.toUpperCase()) == null
  }

  def "login should be case insensitive"() {
    given:
    final user = new User(login: "newuser", password: "newuser")
    userRepository.saveAndFlush(user)

    when:
    final loggedUser = userRepository.login("NEWUser", "newuser")

    then:
    loggedUser.login == user.login
  }

  def "should detect if user has role"() {
    given:
    final role = new Role(name: "role 1")
    final otherRole = new Role(name: "otherRole")
    final user = new User(
      login: "login",
      password: "password",
      roles: [role] as Set)

    and:
    roleRepository.save([role, otherRole])
    userRepository.saveAndFlush(user)

    expect:
    userRepository.userHasRole(user.login, role) == true
    userRepository.userHasRole(user.login, otherRole) == false
  }
}
```

This is it now have tests which will fail in case of query has changed. It is safe to refactor and
optimize. We are also future proof in case of any db or model change we will know from CI tool when
something is wrong. What's more with few additional steps we will be able to make sure everything
will work on production like db.

To make it (almost) work all we need to do is to introduce RepositorySpecification:

```java
@Transactional
@SpringApplicationConfiguration([RepositoryTestingApplication.class, TestConfiguration.class])
@TestPropertySource(properties = ["spring.profiles.active=dev,test"])
abstract class RepositorySpecification extends Specification {
  @Configuration
  static class TestConfiguration {
    @Bean
    @Profile("test")
    public FlywayMigrationStrategy migrationStrategy() {
      return { flyway ->
        flyway.clean();
        flyway.migrate();
      }
    }
  }
}
```

That's all repository specification is ready. Not much here either. We create test spring context
and we use custom FlywayMigrationStrategy to make sure that postgres is cleared before migrations.

Now we are almost ready to go there is only one additional step. We need configuration:

```
# application.properties
spring.profiles.active = dev

spring.jpa.hibernate.ddl-auto = validate
spring.jpa.show-sql = true

flyway.locations = ${db.migrations}
```

Note that by default we are running with dev profile and we load flyway 
migrations from property named db.migrations.

```
# application-dev.properties
spring.jpa.hibernate.ddl-auto = none

spring.datasource.url = jdbc:h2:mem:tmp
spring.datasource.username = sa
spring.datasource.password =

db.type = h2
db.migrations = db/migrations/core

```

dev profile means that we run on in memory h2 database and we skip schema
validation.

```
# application-postgres.properties
spring.datasource.url = jdbc:postgresql://localhost:5432/postgres
spring.datasource.username = postgres
spring.datasource.password = secretpassword

db.type = postgres
db.migrations = db/migrations/core
```

postgres profile differs only in DB connection details. But you can load custom migrations scripts
on h2 and completely different on postgres. You can easily implement custom scripts which will work
with both databases. There is more. On dev environment you can load sample data to fill up database
with something which will make application look like live.

The last step is database truncate before tests. If you load data as migrations step we should get
rid of it to make sure that your tests are not coupled with test data which might be modified in the
future.

```
# application-test.properties
flyway.locations = ${db.migrations},db/migrations/truncate/${db.type}
```

When running test profile all we need is default DB setup for "parent" profile with one additional
step - truncate database. With db.type property it's possible to load dedicated scripts responsible
for DB truncating. DB (truncate scripts are in git).

in order to run tests against h2 db all you need to do is: ```./gralew test``` which is the same to
running: ```./gradlew test -Dspring.profiles.active=dev,test``` It's easy to start tests on
postgres: ```./gradlew test -Dspring.profiles.active=postgres,test``` On your localhost you will be
able to work fast (applying 100+ migrations to in memory H2 is faster than working with traditional
DB) and your CI environment will handle testing application on production like DB.


# Summary

With this pretty simple setup you can test your application against h2 and postgres database. In
case of local environment and simple changes you will not need to bother yourself with postgres. It
might be easy for you to run your application on postgres in docker on linux, but using docker on
windows is not as continent (try to explain to css magician that he needs to install virtual box,
than docker, then run postgres in docker in order to fix up text alignment).
