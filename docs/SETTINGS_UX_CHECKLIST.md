# Settings UX Consistency Checklist

Use this checklist when adding or updating Settings tabs.

## Navigation and Drill-Down

- Use drill-down rows consistently for secondary pages.
- Keep row anatomy consistent: title, optional short subtitle, disclosure indicator.
- Ensure keyboard navigation works (Tab/Arrow/Enter/Escape) for rows and detail pages.
- Avoid nested scroll behavior that causes clipping or jumpy layout.

## Information Hierarchy

- Put the primary action or decision at the top of each group.
- Keep supporting descriptions short and scannable.
- Add context callouts when users enter a deeper configuration page.
- Avoid repeating long explanatory text in multiple places.

## Interaction and Motion

- Provide immediate interaction feedback for navigable rows and important controls.
- Use subtle spring/ease motion only to clarify focus or navigation.
- Respect Reduce Motion accessibility settings.
- Prevent accidental action overload in dense sections.

## States and Feedback

- Every dynamic block should expose loading, empty, success, or warning states.
- Error and warning callouts must provide a clear next action.
- Keep destructive actions visibly destructive and separated from neutral actions.
- Confirm that active/preview states are visibly explicit while running.

## Accessibility

- Combine title/description semantics for row announcement in VoiceOver.
- Add clear accessibility hints for rows that open detail pages.
- Verify focus order and labels on all inputs and actions.
- Avoid ambiguous icon-only actions without accessibility labels.

## Visual Cohesion

- Keep spacing/radius/stroke consistent with design system tokens.
- Prefer semantic colors and materials over hardcoded styling.
- Avoid creating one-off containers when an existing `MA*` component fits.
- Keep list and card compositions intentional to avoid visual noise.
