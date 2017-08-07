---
title: "Learning from the legacy code"
Tags: ["development"]
Categories: ["best practices"]
description: "Don't be afraid of the legacy code there is a lot to learn in there"
date: "2017-06-27"
---

We all love to write new stuff and learn about things. But when we've got to do something in one of
the older applications we'd rather avoid it and lag as long as possible hoping that someone else
will handle it. You shouldn't be afraid of legacy code (as long it is not [ball of
mud](https://tommcfarlin.com/wp-content/uploads/2014/08/xbig-ball-of-mud.jpg.pagespeed.ic.FH0nXJQELT.jpg)).
You should take the opportunity to look into the past, and learn from it as much as possible.

<!--more-->

<center>
![Commandos in the mud](/images/content/201706/learning-from-legacy/soliders-mud.jpg)
</center>

First of all, let's distinguish good and bad legacy code. Working with poorly designed code is
hardly ever good experience and you will be happy once you are done with it but remember that even
javascript [has good
parts](http://xahlee.info/comp/i/JavaScript_books_definitive_guide_vs_good_parts.jpg). If you'll try
hard enough you might find something worth reading in not so good legacy code as well. The good
legacy code is code that uses old libraries or some weird stuff that should stay in the closet but
gets the job done. It still works on production and is mature enough to make you feel old ;) You
shouldn't be afraid of the project just because it uses spring v3 or is written in java6 or older.
Patterns from which you should learn are technology independent.

When reading or working with good legacy code you can look at the software you produce on daily
basis from the perspective. There are a lot of things you can learn from old code but be aware that
learning curve might be very steep.

First of all, find out good parts, don't focus on frameworks or libraries (they do change and
evolve) but try to locate patterns and classes that do work. Figure out how they were applied and
how they work with each other. Think what would you do differently find out how it is tested (if it
is) and finally try to figure out why the author decided to do it this particular way.

If it gets the job done then there is a lesson for you. Applied patterns are probably still valid
and it is something worth remembering. It might come in handy in the future when you will face a
similar problem you'll know that there is a solution which can be applied and that it works just
fine on the production system. Reusing old code without changing a thing might not be the best idea
(especially when the code is based on some old framework or ancient language version) but another
iteration of a good solution will usually be better than previous one. Starting from existing battle
tested code will give you a head start because "trying to figure out this shit phase" will be almost
done.

<center>
![Practice creative thining](/images/content/201706/learning-from-legacy/ideas.jpg)
</center>

On the other hand when the solution you've found doesn't work and it is troublesome, hard to
understand, test or maintain. Then it is an even more valuable lesson. The best way of learning is
from the mistakes especially when they are not yours. Note what went wrong, try to find out why the
solution doesn't work as expected and what went south. If it is poorly designed code stop and think
for a moment what would you do with it? How it should be refactored or rewritten. It is not about
questioning and redoing everything (if you have enough time then why not) but more about practicing.
You don't need a white board for it (unless it is the way you work) just try to think about the
problem and how would you do it. If the problem is small enough then it shouldn't take a lot of time
if it is big one stop early with a high level idea. It's not about figuring out new system design
but challenging yourself and getting used to being more creative. First few times might be very
painful but it gets easier every time you do it. The idea is similar to writing [10 ideas every
day](http://www.jamesaltucher.com/2014/05/the-ultimate-guide-for-becoming-an-idea-machine/). With
time you'll be more creative and solving problems will be easier because you'll have a lot of
practice.

If you don't feel up to the task start small. See ugly class. Every project has at least few of
them. Think how'd you refactor it. Find few things that should be done at the beginning of the
refactoring. Figure out how'd you change it to be more elegant. If you have time you should try and
actually refactor it after planning phase (always remember about [the boy scout
rule](http://programmer.97things.oreilly.com/wiki/index.php/The_Boy_Scout_Rule) - if you have time
try to make code base better place).

Another thing you should note is how the author wrote the code. How it is organized and how it is
tested. It is not only bitching about missing tests or weird interactions. It is about learning from
the past. If modules are not organized in the way that lets you find what you are looking for, then
there is a lesson to learn. Think how would you reorganize the code so that next person would not be
confused. If there are missing test then find out what is missing and why it is important - you'll
know on what you should focus your attention in the future. If tests are fragile try to figure out
what should be changed to make them stable.

<center>
![Creepy clown](/images/content/201706/learning-from-legacy/creepy-clown.jpg)
</center>

The last thing that will give you perspective is to try and compare old code with what you write
every day. Try to imagine that someone will have to work with the new shiny system long after you've
moved on (["Always code as if the guy who ends up maintaining your code will be a violent psychopath
who knows where you live." - John
Woods](https://blog.codinghorror.com/coding-for-violent-psychopaths/)). Think how the poor soul will
feel. Are you leaving something that will work and will defend itself in time or are you producing a
big ball of mud which might work when it is under active development and then will rot super fast?


It is impossible to write perfect code because no one is perfect. Working with old code is not
always a pleasant experience but sometimes you can learn a thing or two from it, and pickup
something interesting.

<small>
Picture credits:

* https://www.pexels.com/photo/water-usa-america-military-33620/
* https://www.pexels.com/photo/light-bulbs-light-order-26943/
* https://www.pexels.com/photo/clown-creepy-grinning-facepaint-39242/
</small>
