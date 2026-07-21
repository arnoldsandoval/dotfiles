# Custom anatomy preview pattern

Use a custom preview when the anatomy needs behavior or rendering that the static `Anatomy` and `AnatomyPart` components cannot provide.

## Use a custom preview for

- Hover or focus highlights between a preview and a side rail.
- Lettered or positioned callouts over a live component.
- React state, DOM measurement, browser-only APIs, or image import normalization.
- A design-system component that needs router context or Astro hydration.
- Reusable Storybook coverage for the anatomy preview itself.

## Avoid a custom preview for

- Static screenshot or SVG diagrams.
- Simple labeled legends.
- Basic anatomy text that can be represented with `AnatomyPart`.

## File structure

```txt
packages/patterns/src/<ComponentName>/
  <ComponentName>.tsx
  <ComponentName>.css        # optional
  <ComponentName>.stories.tsx
  illustration.png           # optional local asset
```

Export from `packages/patterns/src/index.ts`:

```ts
export { ComponentName } from "./ComponentName/ComponentName.js";
export type { ComponentNameProps } from "./ComponentName/ComponentName.js";
```

## MDX insertion

```mdx
import { Anatomy } from "@repo/site-theme/components";
import { ComponentName } from "@repo/patterns";

## Anatomy

<Anatomy fill caption="Anatomy of [surface name].">
  <ComponentName client:load />
</Anatomy>
```

Use `client:load` when the component has interaction or depends on React hydration. If it is completely static React markup, prefer avoiding a custom preview and use docs-native components instead.

## Implementation notes from `InterventionAnatomy`

- Keep the real surface kit-owned where possible. For interventions, use `ModalSdui` instead of recreating modal chrome.
- Put component-scoped layout and marker styles in a local CSS file imported by the component.
- For Astro and Storybook image compatibility, normalize PNG imports:

  ```ts
  const imageSrc = typeof imageAsset === "string" ? imageAsset : imageAsset.src;
  ```

- If a design-system `LinkSdui` is used in an Astro island, it may need React Router context. Reuse an existing router when present and add a small `MemoryRouter` fallback when necessary.
- Keep callout data close to the component and use typed arrays for labels, positions, and descriptions.
- Preserve accessibility: label the section, keep decorative markers `aria-hidden`, and make interactive rail rows keyboard focusable when hover has a focus equivalent.

## Validation checklist

- Component exports from `@repo/patterns`.
- Storybook story imports and renders the preview.
- MDX imports `Anatomy` from `@repo/site-theme/components`.
- MDX imports the preview from `@repo/patterns`.
- Interactive previews use `client:load`.
- `packages/patterns/src/assets.d.ts` supports any new asset import types.

