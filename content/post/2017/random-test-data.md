---
title: "Problem with random test data"
Tags: ["java", "tdd"]
Categories: ["java"]
description: "Problem with random test data"
date: "2017-06-13"
---

Some time ago I noticed new library in our code base - [Random
Beans](https://github.com/benas/random-beans) which as the name suggests is a tool developed to
easily create random data and random objects for testing purposes. Unfortunately, we used it in the
wrong way. Here's how we backed up from the random test data to regain control over testing.

<!--more-->

# tl;dr

Don't use random data to populate objects with logic. <small>Thanks captain obvious ;)</small>.
Random tests input is not a good idea because:

* if with particular test input you expected specification to fail then its corner case and should
  be handled in the dedicated and descriptive test case 
* if the input doesn't really matter why not provide it in plain text for the sake of readability.
  If you really need random data why not [roll the dice](https://xkcd.com/221/) ;)
* if tests will fail for some reason would you be able to reproduce input  which caused failure 
  or will it be expected 'X' but got 'Y' and that's all?
* are you sure that random input doesn't make your tests harder to understand and easier to break?

# The story

To quickly bootstrap project we used random data generator to produce domain objects - I know it
sounds bad. At first, it looked promising and saved few key strokes, but it didn't take long to
fail. The problem revealed itself when I introduced to initially stupid simple domain some business
logic. We had few tests already in place but they were not depending on internal object state, but
rather focusing on interactions. I created a small subcontext for the new feature in the new package
and once I started to integrate my code into existing domain tests started to fail randomly. I'm not
sure what I expected. I asked for some randomness, didn't I?

# The solution

At first, I wanted to exclude some fields from generation process and set values manually and then I
realized that's no good because there are a lot of tests and with each one of them I will be forced
to break encapsulation (which is dangerously easy in groovy...). Then I decided it is time to
fallback to old good object factories. With object factories you are sure that initialized instances
are valid business objects and with a bit of a effort you'll be able to use the same code for tests
objects creation, which is a big plus.

Consider flowing class (in our production application we had more fields to populate and state which
revealed problem):

{{<highlight java>}}
class Article {
  private final Clock clock;

  @Getter
  private LocalDateTime lastUpdateTime;
  private State articleState;

  private String content;

  public Article(Clock clock) {
    this.clock = clock;

    this.articleState = State.IN_PROGRESS;
    this.lastUpdateTime = getCurrentDateTime();
  }

  public void updateContent(String newContent) {
    Preconditions.checkState(articleState.canSave());
    this.content = newContent;
    this.lastUpdateTime = getCurrentDateTime();
  }

  public void sendForApproval() {
    Preconditions.checkState(articleState.canSendForApproval());
    this.lastUpdateTime = getCurrentDateTime();
    this.articleState = State.WAITING_FOR_APPROVAL;
  }

  private LocalDateTime getCurrentDateTime() {
    return LocalDateTime.now(clock);
  }

  private enum State {
    APPROVED, REJECTED, IN_PROGRESS, WAITING_FOR_APPROVAL;

    boolean canSave() {
      return this == IN_PROGRESS || this == REJECTED;
    }

    boolean canSendForApproval() {
      return this == State.IN_PROGRESS;
    }
  }
}
{{</highlight>}}

In perfect world you should be able to just do: new Article() and be done with it, but sometimes
it's not that simple and object creation might depend on external factors which are inconvenient or
impossible to provide in constructor, especially when you create article instances from many places,
or you want to mock some stuff for testing purposes. That's when object factories come into play.

You can easily create article instances with ArticlesFactory:

{{<highlight java>}}
@RequiredArgsConstructor
class ArticleFactory {
  private final Clock systemClock;

  public ArticleFactory() {
    this(Clock.systemDefaultZone());
  }

  public Article newArticle() {
    return new Article(systemClock);
  }
}
{{</highlight>}}

Now when you have production objects factory you can reuse its logic for test data creation:

{{<highlight java>}}
public class TestArticleFactory {
  private static Clock fixedTime = new MutableClock();

  public static Article newArticle(Clock clock) {
    return new ArticleFactory(clock).newArticle();
  }

  public static Article newApprovedArticle() {
    return newApprovedArticle(fixedTime);
  }

  public static Article newApprovedArticle(Clock clock) {
    final Article article = newArticle(clock);
    article.sendForApproval();
    return article;
  }
}
{{</highlight>}}

And that's all. Note that from now on you can easily add additional logic to your test data
factories to properly initialize objects and prepare them for the testing phase. You'll need to
produce some extra code (comparing to a raw groovy solution) but you are sure that objects created
for your tests are the same objects you'll use in the production application and in the long run
when the domain changes all you'll need to do is fix factory to produce what is expected from it.

<small>[samples](https://github.com/pchudzik/blog-example-random-test-input)</small>