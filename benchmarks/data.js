window.BENCHMARK_DATA = {
  "lastUpdate": 1757257377341,
  "repoUrl": "https://github.com/munishgandhi/n8n-mcp-hyly",
  "entries": {
    "n8n-mcp Benchmarks": [
      {
        "commit": {
          "author": {
            "email": "56956555+czlonkowski@users.noreply.github.com",
            "name": "Romuald Członkowski",
            "username": "czlonkowski"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "9e79b53465fc9c5ea368a316e14e52161b45e529",
          "message": "Merge pull request #178 from amauryconstant/feature/add-readonly-isArchived-property\n\nAdd isArchived field to workflow responses and types",
          "timestamp": "2025-09-04T15:42:20+02:00",
          "tree_id": "f25f250fb33a322faeed9f0fc4abf58cbb6f6f5b",
          "url": "https://github.com/munishgandhi/n8n-mcp-hyly/commit/9e79b53465fc9c5ea368a316e14e52161b45e529"
        },
        "date": 1757257377003,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "sample - array sorting - small",
            "value": 0.0187,
            "range": "0.35",
            "unit": "ms",
            "extra": "53437 ops/sec"
          },
          {
            "name": "sample - array sorting - large",
            "value": 3.1677,
            "range": "0.5105",
            "unit": "ms",
            "extra": "316 ops/sec"
          },
          {
            "name": "sample - string concatenation",
            "value": 0.0049,
            "range": "0.2879",
            "unit": "ms",
            "extra": "204185 ops/sec"
          },
          {
            "name": "sample - object creation",
            "value": 0.0658,
            "range": "0.29569999999999996",
            "unit": "ms",
            "extra": "15187 ops/sec"
          }
        ]
      }
    ]
  }
}