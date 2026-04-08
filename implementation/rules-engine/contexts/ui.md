Before claiming UI work is complete, verify:

1. LOOK AT IT. Take a screenshot or navigate to the page and describe what you actually see. Not "the page renders" — what does it look like? Is the layout correct? Is the text readable? Are elements aligned?

2. Check at 375px width (mobile). If there is a sidebar, menu, or table, does it behave at narrow viewports? Overflow is the most common miss.

3. Is real data showing, or placeholder/dummy content? If the component fetches data, what does it display during loading? What does the empty state look like (zero items)?

4. If this involves user input, what happens on submit with empty fields? With invalid input? Is there feedback?

5. Show evidence of what you see — describe the actual visual state, not just that the dev server is running.
