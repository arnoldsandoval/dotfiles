---
name: tdc-anatomy-component
description: Create and insert Trust Design Core anatomy sections into docs pages. Use when adding an Anatomy block to an MDX page, creating anatomy callouts/parts, inserting a screenshot/SVG anatomy, or scaffolding a custom interactive anatomy preview component for the Trust Design Core docs site.
---

# Trust Design Core Anatomy Component

You help page authors add anatomy sections to Trust Design Core documentation pages.

Prefer the existing docs components first. Only scaffold a custom React preview when static MDX anatomy cannot express the surface, behavior, or callout layout.

## Required reading

Before editing, read:

1. `references/anatomy-components.md` — existing `Anatomy` and `AnatomyPart` APIs.
2. `references/custom-preview.md` — when and how to scaffold a custom preview component.

## Step 1: Classify the anatomy request

Choose one path:

| Request shape | Path |
| --- | --- |
| Page needs a screenshot, SVG, simple visual, or existing component inside an anatomy frame | **Static anatomy** |
| Page needs a side-by-side legend using standard numbered parts | **Static anatomy with parts** |
| Page needs hover/focus highlights, measured callouts, custom image normalization, React state, or Storybook coverage | **Custom preview component** |

If the request does not specify labels or body copy for anatomy parts, infer a sensible first draft from the page context and tell the user what you chose. Do not block unless the missing information changes the implementation path.

## Step 2: Find the target page

Use the repository root as the working directory.

1. Locate the target `.mdx` page under `apps/site/src/content/docs/`.
2. Read the current imports and nearby headings.
3. Preserve the existing page structure and place the anatomy section near the page's conceptual overview unless the user specifies another location.

## Step 3: Add static anatomy when possible

Use this path for most requests.

1. Import the docs components:

   ```mdx
   import { Anatomy, AnatomyPart } from "@repo/site-theme/components";
   ```

   If the page already imports from `@repo/site-theme/components`, merge `Anatomy` and `AnatomyPart` into that import instead of adding a duplicate.

2. Insert an anatomy block:

   ```mdx
   <Anatomy fill caption="Anatomy of [surface name].">
     [visual content]

     <Fragment slot="parts">
       <AnatomyPart label="Title">
         Names the situation in member terms.
       </AnatomyPart>
       <AnatomyPart label="Body">
         Explains what happened, what it means, and what comes next.
       </AnatomyPart>
     </Fragment>
   </Anatomy>
   ```

3. Use `fill` when the preview should sit on the soft neutral anatomy background. Omit `fill` for image-only anatomy that needs a bordered white frame.
4. Use concise labels and one-sentence descriptions. Anatomy parts explain structure, not product copy.

## Step 4: Scaffold a custom preview only when needed

Use this path when static MDX is not enough.

1. Create a component folder under `packages/patterns/src/<ComponentName>/`.
2. Add `<ComponentName>.tsx` and, if needed, `<ComponentName>.css` and local assets.
3. Export the component and props from `packages/patterns/src/index.ts`.
4. Add a Storybook story under the component folder.
5. Insert into the MDX page:

   ```mdx
   import { Anatomy } from "@repo/site-theme/components";
   import { ComponentName } from "@repo/patterns";

   <Anatomy fill caption="Anatomy of [surface name].">
     <ComponentName client:load />
   </Anatomy>
   ```

Use `client:load` for React components with interaction, state, browser measurement, or router-dependent design-system components.

## Step 5: Validate

Run only existing repo commands. Choose the narrowest commands that cover the files changed:

```sh
yarn exec prettier --write <changed files>
yarn tsc -p packages/patterns/tsconfig.json --noEmit
yarn turbo run build --filter=site --filter=storybook --filter=@repo/site-theme
```

If the change is MDX-only and does not touch `packages/patterns`, the site build is usually enough:

```sh
yarn turbo run build --filter=site --filter=@repo/site-theme
```

## Success criteria

- The target page imports anatomy components from the correct package.
- The anatomy block renders inside the docs `Anatomy` frame.
- Anatomy parts use `AnatomyPart` and the `parts` slot when a legend is needed.
- Custom preview components are exported from `@repo/patterns` and have a Storybook story.
- Interactive React previews use the correct Astro client directive.
- Formatting and relevant builds pass.

