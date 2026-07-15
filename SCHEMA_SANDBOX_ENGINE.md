# Revised Firestore Schema — Sandbox Level Engine

## lessons/{lessonId}
```
{
  teacherUid: string,
  title: string,
  subject: "reading" | "listening" | "speaking" | "writing" | "arithmetic",
  ageGroup: "4-5" | "5-6" | "6-7",
  createdAt: Timestamp,

  // NEW: map theming — falls back to the built-in theme for the subject
  // (Farm/Savanna/Jungle/Space/Ocean) if the teacher hasn't customized it.
  mapConfig: {
    theme: "farm" | "savanna" | "jungle" | "space" | "ocean" | "custom",
    backgroundUrl: string | null,   // teacher-uploaded background; null = use built-in theme asset
  },

  // Words now carry position + optional network image + math script.
  words: [
    {
      text: string,               // e.g. "CAMEL"
      imageUrl: string | null,     // teacher-uploaded PNG; null = fall back to bundled asset by name match
      imageAsset: string | null,   // legacy/bundled fallback (existing 84-image picker)
      positionX: number,           // 0.0–1.0 fractional X on the map
      positionY: number,           // 0.0–1.0 fractional Y on the map

      // Arithmetic-only. Ignored for other subjects.
      // Each entry is a signed delta applied in sequence starting from 0:
      // [10, -7, 2] => start empty, spawn 10, remove 7, spawn 2 => ends at 5.
      mathScript: number[] | null,
    }
  ]
}
```

## farmProgress/{kidId}/subjects/{subjectId}
Split per subject (previously a single flat `words` map) so stars don't collide
across subjects if the same word text is reused in two subjects.
```
{
  words: {
    "CAMEL": { stars: 0-3, lastPlayed: Timestamp },
    "LION":  { stars: 2,  lastPlayed: Timestamp },
    ...
  }
}
```

## Migration notes
- Existing `lessons` docs without `mapConfig`/`positionX`/`positionY` are treated
  as `theme: subject-default` and auto-laid-out in a grid (see FarmMapScreen
  fallback logic) — no backfill migration required, old lessons keep working.
- `imageAsset` stays as the fallback path so lessons created before this change
  keep rendering correctly with zero data migration.
