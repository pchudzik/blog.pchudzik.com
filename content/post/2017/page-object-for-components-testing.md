---
title: "Page object pattern for javascript components testing"
Tags: ["testing", "tdd", "basics", "angular", "howto"]
Categories: ["javascript"]
description: "Using page object patter for angulars directives and react components"
date: "2017-02-23"
---

[Page object
pattern](http://www.seleniumhq.org/docs/06_test_design_considerations.jsp#page-object-design-pattern)
is common practice when writing automated tests using [selenium](http://www.seleniumhq.org/). It
allows to gather all possible operations on page in one place and hide page implementation details
from test case. Page object pattern can be used in the same way for angular directives, react and
[put framework name here] components.
 
 <!--more-->
 
We will be working with simple TODO app with directive responsible for displaying TODO item. I will
focus on item modification which is part of item displaying 'logic'.

The item edition will be triggered when button is clicked and saved. When other button is clicked
modification will be reverted.

We can start with something like this:

{{<highlight javascript>}}
it('should edit item', () => {
  //given
  const scope = $rootScope.$new();
  scope.item = {text: 'Old value'};
  const element = $compile('<todo item="item"></todo>')(scope);
  scope.$apply();
  
  //when
  element.find('button.edit').click();
  element.find('textarea').text('New value');
  element.find('textarea').trigger('change');
  element.find('button.save').click();
  
  //then
  expect(item.text).toEqual('New value');
});
{{</highlight>}}

It works, right? Sure. When reading test code do you care about button class? What will happen with
all 21 tests if button class will be changed from save to save-item?

Let's refactor it to create more readable test.

After second test you should notice that directive creation can be reused.

{{<highlight javascript>}}
function createDirective(item) {
  const scope = $rootScope.$new();
  scope.item = item;
  const element = $compile('<todo item="item"></todo>')(scope);
  scope.$apply();
  
  return element;
}
{{</highlight>}}

With new function we can easily create new directive:

{{<highlight javascript>}}
//given
const item = {text: 'Old value'};
const element = createDirective(item);
{{</highlight>}}

We can go further with this and encapsulate how directive looks and how to trigger actions from the
test.

{{<highlight javascript>}}
function createDirective(item) {
  // initial directive creation code
  element.startItemEdition = () => element.find('button.edit').click();
  element.changeItemText = newText => {
    const textarea = element.find('textArea'); 
    textarea.val(newText);
    textarea.trigger('change');
  }
  element.saveChangedItem = () => element.find('button.save').click();
  // ...
}
{{</highlight>}}

With each iteration it looks better.

{{<highlight javascript>}}
//given
const item = {text: 'Old value'};
const element = createDirective(item);

//when
element.startItemEdition();
element.changeItemText('New value');
element.saveChangedItem();

//then
expect(item.text).toEqual('New value');
{{</highlight>}}

More complex operations can be gatherd in single function hidden inside createDirective function:

 {{<highlight javascript>}}
function createDirective(item) {
  // initial directive creation code
  
  element.modifyItem = (newText) => {
    element.startItemEdition();
    element.changeItemText(newText);
    element.saveChangedItem();
  }
  
  return element;
}
{{</highlight>}}

Now test is very easy to read:

{{<highlight javascript>}}
//given
const item = {text: 'Old value'};
const element = createDirective(item);

//when
element.modifyItem('New value');

//then
expect(item.text).toEqual('New value');
{{</highlight>}}

With existing methods it will be easy to test modification abort.

{{<highlight javascript>}}
//given
const item = {text: 'Old value'};
const element = createDirective(item);

//when
element.startItemEdition();
element.changeItemText('New value');
element.cancelItemEdition(); //element.cancelItemEdition = () => element.find('button.cancel').click()

//then
expect(item.text).toEqual('Old value');
{{</highlight>}}

With this approach we are not restricted only to action execution. We can also encapsulate
verifications. When item priority is high then background should be red.

{{<highlight javascript>}}
//given
const item = {text: 'text', priority: 'urgent'};

//when
const element = createDirective(item);

//then
expect(element.isHighlighted()).toEqual(true);    //element.isHighlighted = () => element.hasClass('important');
{{</highlight>}}

When reading test do you really care about the shade of red? Or if it is css class. It doesn't
matter. The important thing is that item must be highlighted. How it's achieved will be eventfully
checked but it's not critical information when reading test code.

Using this approach it is easier to practice TDD. You can write your tests first and worry about
implementation details letter when you decide what will be class name, or html layout.

Page object pattern can be very useful for testing angular directives and react components. With
proper encapsulation all tests should be easier to maintain, refactor and read.
