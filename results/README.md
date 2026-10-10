# Results

Each file here, apart from those in `before-merging-near-twins/`, is written by a test in `Tests/StatsAgentTests/` and holds its latest run. A file starts with what the run did and how it's scored, then the scores, then the misses or every run. Most runs ask each question three times, with the options in a different seeded order each time, and greedy sampling, so a run repeats exactly.

The experiments are listed below in the order they were run, each with the files that hold its results.

## Question sets

- The placeholder catalog's 31 questions, in [`SelectionCases`](../Tests/StatsAgentTests/SelectionCases.swift), and two rounds of paraphrases of them: [round 1](../prompts/raw/paraphrases-round-1.md), [round 2](../prompts/raw/paraphrases-round-2.md).
- The 57 stats questions, labelled in [`StatsQuestionCases`](../Tests/StatsAgentTests/StatsQuestionCases.swift): [40 questions a blogger might ask](../prompts/raw/stats-questions-round-1.md), [15 that stats probably don't track](../prompts/raw/stats-questions-untracked-round-1.md), and two hand-written ones.
- [Two paraphrases of each of the 57](../prompts/raw/stats-paraphrases-round-1.md), [40 later questions](../prompts/raw/stats-questions-round-2.md) and [12 questions only insights answers](../prompts/raw/stats-questions-insights-round-1.md).
- Questions for the span step: [naming spans](../prompts/raw/stats-questions-spans-round-1.md), [naming none](../prompts/raw/stats-questions-no-span-round-1.md), [about subscribers](../prompts/raw/stats-questions-subscribers-round-1.md) and [about visits](../prompts/raw/stats-questions-visits-round-1.md).
- The made-up stats the answer in words is written from, in [`AnswerTextCases`](../Tests/StatsAgentTests/AnswerTextCases.swift).

## One list or a pyramid

The placeholder catalog, picked from in one call at sizes 8 to 86, and as an area and then an option in it.

- [`flat-selection.txt`](flat-selection.txt)
- [`pyramid-selection.txt`](pyramid-selection.txt)

## "None of these" and backing up

- [`pyramid-backtracking.txt`](pyramid-backtracking.txt)

## New wording

The three approaches on each round of paraphrases.

- [`paraphrases-round-1/`](paraphrases-round-1/)
- [`paraphrases-round-2/`](paraphrases-round-2/)

## Merging near-twins

The step that picks the figure for "stats on a day", and the selection files from before the merge, when the catalog had 89 options. The selection files above are from after it. No test writes the files from before the merge, since the catalog they ran on is no longer in the code.

- [`day-metric.txt`](day-metric.txt)
- [`before-merging-near-twins/`](before-merging-near-twins/)

## Real stats endpoints, and what they return

The 21 endpoints described by what each is about ("blind"), and by what each returns as well ("sighted").

- [`stats-endpoints/blind.txt`](stats-endpoints/blind.txt)
- [`stats-endpoints/sighted.txt`](stats-endpoints/sighted.txt)

## The operation step

- [`stats-endpoints/sighted-with-operations.txt`](stats-endpoints/sighted-with-operations.txt), and on the paraphrases, [`stats-endpoints/stats-paraphrases-round-1/sighted-with-operations.txt`](stats-endpoints/stats-paraphrases-round-1/sighted-with-operations.txt)
- The questions this setup gets right in most orders, and the ones it gets wrong: [`questions-mostly-right.md`](stats-endpoints/questions-mostly-right.md), [`questions-mostly-wrong.md`](stats-endpoints/questions-mostly-wrong.md)

## Reshaping the endpoints

Each variant has a file for the 57 questions in `stats-endpoints/` and one for the paraphrases in `stats-endpoints/stats-paraphrases-round-1/`, under the same name.

- Each endpoint's time span stated: `sighted-scoped-with-operations.txt`, and without the operation step, [`stats-endpoints/sighted-scoped.txt`](stats-endpoints/sighted-scoped.txt)
- Summary and insights split into focused options: `sighted-split-with-operations.txt`
- One endpoint for each kind of question: `sighted-one-home-with-operations.txt`
- Without insights: `sighted-without-insights-with-operations.txt`
- Without summary: `sighted-without-summary-with-operations.txt`
- The questions only insights answers, with all the endpoints and without insights or summary: [`stats-endpoints/stats-questions-insights-round-1/`](stats-endpoints/stats-questions-insights-round-1/)

## A catalog we wrote ourselves

The stats picked by what's counted and how it's split, with labels in [`DataCatalogLabels`](../Tests/StatsAgentTests/DataCatalogLabels.swift).

- [`data-catalog/with-operations.txt`](data-catalog/with-operations.txt), and on the paraphrases, [`data-catalog/stats-paraphrases-round-1/with-operations.txt`](data-catalog/stats-paraphrases-round-1/with-operations.txt)
- The 40 later questions, with this catalog and with the endpoints: [`data-catalog/stats-questions-round-2/with-operations.txt`](data-catalog/stats-questions-round-2/with-operations.txt), [`stats-endpoints/stats-questions-round-2/sighted-with-operations.txt`](stats-endpoints/stats-questions-round-2/sighted-with-operations.txt)
- The questions only insights answers: [`data-catalog/stats-questions-insights-round-1/`](data-catalog/stats-questions-insights-round-1/)

## The operation from the question alone

The files named `question-only-operations.txt` in `data-catalog/` and its subfolders, and `sighted-question-only-operations.txt` in `stats-endpoints/` and its subfolders.

- [`stats-endpoints/sighted-question-only-operations.txt`](stats-endpoints/sighted-question-only-operations.txt)
- [`data-catalog/question-only-operations.txt`](data-catalog/question-only-operations.txt)

## Up to three picks

One pick and a list of up to three, at the endpoint step alone, and what the app's combination of the two shows, read back from both.

- [`stats-endpoints/multi-pick.txt`](stats-endpoints/multi-pick.txt), and on the paraphrases, [`stats-endpoints/stats-paraphrases-round-1/multi-pick.txt`](stats-endpoints/stats-paraphrases-round-1/multi-pick.txt)
- [`stats-endpoints/multi-pick-gate.txt`](stats-endpoints/multi-pick-gate.txt)

## Calls at the same time

- [`concurrency.txt`](concurrency.txt)

## Spans

The span step, and for visits, the step that picks the figure.

- [`spans.txt`](spans.txt)
- [`visits-metric.txt`](visits-metric.txt)

## The answer in words

- [`answer-text.txt`](answer-text.txt)
