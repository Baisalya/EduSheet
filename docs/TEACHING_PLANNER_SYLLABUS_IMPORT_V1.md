# Teaching Planner — Syllabus Import Format v1

Phase 14 imports a syllabus as a **new class**. Existing planner data is never replaced.

## File contract

The root object must contain:

- `format`: `edusheet.syllabus`
- `version`: `1`
- `class`: object with required `name` and optional `academicYear`
- `subjects`: array

Each subject supports:

- `name` (required)
- `code` (optional)
- `units` (array)
- `chapters` (array for subject-level chapters with no unit)

Each unit supports:

- `title` (required)
- `plannedPeriods` (optional, default `0`)
- `priority`: `low`, `normal`, or `high` (optional, default `normal`)
- `chapters` (array)

Each chapter supports:

- `title` (required)
- `plannedPeriods` (optional, default `0`)
- `priority`: `low`, `normal`, or `high` (optional, default `normal`)
- `topics` (array)

Each topic supports:

- `title` (required)
- `plannedPeriods` (optional, default `0`)
- `priority`: `low`, `normal`, or `high` (optional, default `normal`)

Imported records receive **new stable IDs**. Existing lesson/progress fields are intentionally not imported in Phase 14; imported topics start as `Planned` with zero actual periods.

## Example

```json
{
  "format": "edusheet.syllabus",
  "version": 1,
  "class": {
    "name": "Class 10",
    "academicYear": "2026-27"
  },
  "subjects": [
    {
      "name": "Mathematics",
      "code": "MATH",
      "units": [
        {
          "title": "Number Systems",
          "plannedPeriods": 10,
          "priority": "high",
          "chapters": [
            {
              "title": "Real Numbers",
              "plannedPeriods": 6,
              "priority": "high",
              "topics": [
                {
                  "title": "Euclid Division Lemma",
                  "plannedPeriods": 2,
                  "priority": "high"
                },
                {
                  "title": "HCF and LCM",
                  "plannedPeriods": 2,
                  "priority": "normal"
                }
              ]
            }
          ]
        }
      ],
      "chapters": [
        {
          "title": "Introduction",
          "plannedPeriods": 1,
          "priority": "normal",
          "topics": []
        }
      ]
    }
  ]
}
```

## Templates

Phase 14 does not ship curriculum-specific templates. The Phase 13 repository has no existing template catalogue, so no syllabus content is invented. A blank syllabus is created through **Class → Subject → Unit/Chapter → Topic** in the manager.
