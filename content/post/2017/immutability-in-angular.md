---
title: "Immutability in angular"
Tags: ["angular", "basics"]
Categories: ["javascript"]
description: "Using immutable data structures to process user actions"
date: "2017-07-11"
---

Some time ago I've been struggling with mapping hierarchical data structure in angular. Labels
hierarchy was complex (like 4 levels deep with multiple parents, multiple children, basically graph
like structure with some logic behind it). In the end it was/is still working but that's the
best I can say about it.

<!--more-->

Lately I've got a chance to implement something similar in new application. I could've copied previous
solution with all it's problems but since I was not happy about it I decided to do something
different. My initial problem might look like this labels hierarchy:

```
 X  Y
 \  /
  Z
 / \
K   L
```

When X changes we should check available Z values, when Z values are modified then K and L labels
must be updated. Nothing significant happens when K or L values are modified. Labels are always
updated from top to bottom. There are some business rules defined for labels so each time you change
something you should go to the backend and ask it to recalculate possible values. On the frontend
all labels have basically the same.

To keep example simple and in order to clearly explain what I have in mind I'm not going to
implement labels example which will be unnecessary complex. I will do article's categories and tags
assigned to those categories instead. It should be simple enough to show exactly what I have in
mind.

First let's dive into the most important part of the code:

```javascript
function addCategory(category) {
    updateFormState({selectedCategories: [...$scope.formData.selectedCategories, category]});
  }

  function removeCategory(category) {
    updateFormState({selectedCategories: filterOutSelected($scope.formData.selectedCategories, category)});
  }

  function addTag(tag) {
    updateFormState({selectedTags: [...$scope.formData.selectedTags, tag]});
  }

  function removeTag(tag) {
    updateFormState({selectedTags: filterOutSelected($scope.formData.selectedTags, tag)});
  }

function updateFormState(newData) {
  const
    updatedFormData = Object.assign({}, $scope.formData, newData),
    selectedCategories = updatedFormData.selectedCategories,
    selectedTags = updatedFormData.selectedTags.filter(tag => isTagAssignableFrom(tag, selectedCategories)),
    availableCategories = [...initial.availableCategories],
    availableTags = initial.availableTags.filter(tag => isTagAssignableFrom(tag, selectedCategories));

  $scope.formData = {selectedCategories, selectedTags};
  $scope.availableOptions = {
    categories: availableCategories,
    tags: availableTags
  };
}
```

<small>[full
source](https://github.com/pchudzik/blog-example-immutability-in-angular/blob/master/form.ctrl.js)</small>

Nothing fancy you might say, especially if you have some react background, but in the world of
angular it's not the most obvious solution.

The trick is to recalculate all possible values from scratch every time there is user action. In
this simple example it might not look like a lot, but think for a moment about my initial problem
where labels structure was much more complicated. It was really annoying and painful to implement it
using "classic" angular approach. It was even more tedious when I was forced to execute some
asynchronous http calls, another layer of pain was sharing the state between multiple UI components
with asynchronous actions pending in the background... Long story short
[redux](https://github.com/reactjs/redux) inspired approach with recalculating all possible values
every time there is a change was better way of solving the problem and saved me a lot of time.

What I did is not the first thing you'll do in angular. All the examples and tutorials from the
Internet are based on scope and stirring the soup until it is just right. Which turns out to be
messy, hard to maintain and even harder to test. I believe that presented solution will be easier to
understand and extend in the future (there is only one place where state can be modified).

Note that the idea I "implemented" is something inspired by [flux](https://facebook.github.io/flux/)
and [redux](https://github.com/reactjs/redux) and in case of really complicated model you should
consider using proper flux implementation which is possible in angular with
[ng-redux](https://github.com/angular-redux/ng-redux) or if your problem is small enough you can
always implement something on your own which is not as complicated as you might think, unless you
need generic solution.

<small>[code samples](https://github.com/pchudzik/blog-example-immutability-in-angular)</small>