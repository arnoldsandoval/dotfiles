# Anatomy components

Trust Design Core exposes docs-native anatomy components from `@repo/site-theme/components`.

## `Anatomy`

Source: `packages/site-theme/components/custom/Anatomy.astro`

Props:

| Prop | Type | Use |
| --- | --- | --- |
| `src` | `string` | Render an image directly in the anatomy frame. |
| `alt` | `string` | Alt text for `src`; default is empty. |
| `caption` | `string` | Optional figure caption below the frame. |
| `fill` | `boolean` | Uses the soft neutral background and removes the border. |

Slots:

| Slot | Use |
| --- | --- |
| default | Custom content inside the anatomy frame. |
| `parts` | Anatomy legend rendered as an ordered list beside the frame on wider screens. |

The frame is marked `not-content` so Starlight markdown spacing does not leak into custom content.

## `AnatomyPart`

Source: `packages/site-theme/components/custom/AnatomyPart.astro`

Props:

| Prop | Type | Use |
| --- | --- | --- |
| `label` | `string` | The anatomy part label. |

The default slot is the part description. Numbering is automatic through CSS counters, so authors should not type numbers into labels.

## Static anatomy example

```mdx
import { Anatomy, AnatomyPart } from "@repo/site-theme/components";

## Anatomy

<Anatomy fill caption="Anatomy of a safety notice.">
  <img src="/images/safety-notice.png" alt="" />

  <Fragment slot="parts">
    <AnatomyPart label="Title">
      Names the risk in member-facing language.
    </AnatomyPart>
    <AnatomyPart label="Body">
      Explains what happened and what the member can do next.
    </AnatomyPart>
    <AnatomyPart label="Action">
      Gives the member one clear next step.
    </AnatomyPart>
  </Fragment>
</Anatomy>
```

## Image-only anatomy example

```mdx
import { Anatomy } from "@repo/site-theme/components";

<Anatomy
  src="/images/pattern-anatomy.svg"
  alt="Annotated diagram of the pattern structure."
  caption="Anatomy of the pattern."
/>
```

## Import merging

Prefer one merged import:

```mdx
import { Anatomy, AnatomyPart, FeatureCard, FeatureRow } from "@repo/site-theme/components";
```

Avoid duplicate imports from the same package.

