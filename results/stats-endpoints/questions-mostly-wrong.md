# Questions the agent gets wrong in most orders

51 of 183 prompts, right in 0 or 1 of the 3 orders. From the main setup's results, sighted with the operation step: `results/stats-endpoints/sighted-with-operations.txt`, `results/stats-endpoints/stats-paraphrases-round-1/sighted-with-operations.txt`, `results/stats-endpoints/stats-questions-insights-round-1/sighted-with-operations.txt`. Each prompt ran once in each of 3 option orders. A run is right when it ends on an acceptable endpoint with an acceptable operation or, when no endpoint can answer, without an answer. Prompts are grouped by question under its expected answer, the original first and its paraphrases (labels ending in A or B) after it. Endpoint ids are shown without their `stats_` prefix.

## Answerable (41 prompts)

**Expected: visits or summary · value**

- 1/3 r3B: "Add up yesterday's total views." — wrong runs ended on: summary · compare_periods ×2

**Expected: visits · compare_periods**

- 0/3 r6: "How does this month's traffic compare to last month's?" — wrong runs ended on: summary · compare_periods ×3
- 0/3 r6A: "Compare this month's traffic against last month's." — wrong runs ended on: referrers · compare_periods, summary · compare_periods ×2

**Expected: top_posts · rank_items**

- 0/3 r8: "What's my best performing post of all time?" — wrong runs ended on: post · trend ×3

**Expected: visits · value**

- 1/3 r9A: "What was the comment total for last month?" — wrong runs ended on: summary · value ×2
- 1/3 r9B: "Total up the comments I got last month." — wrong runs ended on: summary · value ×2

**Expected: visits or summary · highest_or_lowest_period**

- 1/3 r10A: "What day this week brought in the most visitors?" — wrong runs ended on: insights · value, insights · list_items
- 1/3 r10B: "Pick out the day this week with the highest visitor count." — wrong runs ended on: insights · rank_items, insights · value

**Expected: visits · trend**

- 0/3 r14B: "Walk me through the comment trend for the last three months." — wrong runs ended on: summary · trend ×2, summary · compare_periods

**Expected: visits · highest_or_lowest_period**

- 0/3 r16: "When did I get my biggest traffic spike this year?" — wrong runs ended on: insights · rank_items ×2, insights · list_items
- 0/3 r16A: "What date saw my biggest traffic spike this year?" — wrong runs ended on: insights · list_items ×3
- 0/3 r16B: "Identify when my site had its largest surge in visits this year." — wrong runs ended on: insights · rank_items ×2, insights · list_items

**Expected: country_views · rank_items or compare_periods**

- 1/3 r18: "Which country sends me the most traffic, and has that changed since last year?" — wrong runs ended on: country_views · compare_items ×2
- 1/3 r18A: "What country is my top traffic source, and is that different from last year?" — wrong runs ended on: referrers · compare_periods, region_views · compare_items
- 1/3 r18B: "Tell me which country drives the most visits to my site, and whether that's shifted since last year." — wrong runs ended on: region_views · rank_items ×2

**Expected: emails_summary · trend**

- 0/3 r22B: "Check whether a bigger or smaller share of my list is opening the newsletter lately." — wrong runs ended on: emails_summary · compare_items ×2, post · trend

**Expected: visits · compare_periods**

- 1/3 r24A: "What's different about this week's traffic compared to last week's?" — wrong runs ended on: insights · list_items, none of these
- 0/3 r24B: "Spell out how traffic shifted from last week to this week." — wrong runs ended on: visits · trend, summary · trend, post_comments

**Expected: referrers · rank_items**

- 0/3 r26B: "Name whichever site sends me the most click-throughs these days." — wrong runs ended on: none of these ×2, clicks · rank_items

**Expected: emails_summary · value**

- 1/3 r29A: "What's the open count on my most recent newsletter?" — wrong runs ended on: emails_summary · list_items, emails_summary · rank_items

**Expected: top_posts · rank_items**

- 1/3 r30A: "Which post has performed worst this year?" — wrong runs ended on: none of these ×2

**Expected: post · value**

- 0/3 r33: "Compare the likes on my last three posts." — wrong runs ended on: top_posts · compare_items, post · compare_periods ×2
- 0/3 r33A: "How do the like counts stack up across my last three posts?" — wrong runs ended on: top_posts · compare_items ×2, visits · compare_periods
- 0/3 r33B: "Line up the likes for my three most recent posts." — wrong runs ended on: post_comments ×2, top_posts · rank_items

**Expected: referrers or top_posts · rank_items or list_items or compare_periods**

- 1/3 r34: "My page views seem to have jumped recently — what's driving that?" — wrong runs ended on: insights · list_items ×2
- 0/3 r34A: "Page views look like they've spiked recently — what's behind that?" — wrong runs ended on: summary · trend, post · trend ×2
- 0/3 r34B: "Track down what's behind the recent jump in my page views." — wrong runs ended on: insights · list_items ×3

**Expected: subscribers · trend or highest_or_lowest_period**

- 1/3 r37A: "What point did my subscriber count start declining?" — wrong runs ended on: none of these ×2
- 0/3 r37B: "Pinpoint when I began losing subscribers." — wrong runs ended on: none of these ×3

**Expected: devices_screensize · compare_items**

- 1/3 r39: "How does mobile traffic compare to desktop traffic this month?" — wrong runs ended on: devices_platform · compare_items, devices_browser · compare_periods
- 0/3 r39A: "Compare mobile traffic to desktop traffic this month." — wrong runs ended on: devices_browser · compare_items ×2, devices_browser · compare_periods

**Expected: visits · compare_periods or trend**

- 0/3 r40: "This month's numbers feel off — what's different compared to my usual average?" — wrong runs ended on: summary · compare_periods ×3
- 0/3 r40A: "Something feels off about this month's numbers — how do they differ from my usual average?" — wrong runs ended on: summary · compare_periods ×3

**Expected: devices_screensize · compare_items**

- 1/3 u12A: "Is my audience mostly skimming on mobile, or reading properly on desktop?" — wrong runs ended on: devices_browser · compare_items ×2

**Expected: visits or summary · highest_or_lowest_period**

- 0/3 session-3: "What was my best day - stats-wise - this month?" — wrong runs ended on: summary · trend, insights · list_items, insights · rank_items
- 0/3 session-3A: "Which day had the strongest stats this month?" — wrong runs ended on: insights · list_items ×3
- 0/3 session-3B: "Flag my top day, numbers-wise, for this month." — wrong runs ended on: summary · value ×2, insights · value

**Expected: insights · value or list_items or rank_items**

- 0/3 i7: "How many posts did I get out in 2023?" — wrong runs ended on: top_posts · value, summary · value ×2

**Expected: insights · value or list_items or rank_items**

- 1/3 i8: "Was 2021 a busier writing year for me than 2022?" — wrong runs ended on: summary · compare_periods ×2

**Expected: insights · value or list_items or rank_items**

- 1/3 i11: "On average, how many comments did each post rack up in 2020?" — wrong runs ended on: post · trend, post · compare_periods

**Expected: insights · value or list_items or rank_items**

- 1/3 i12: "Did people respond more to what I posted in 2024 than back in 2019?" — wrong runs ended on: summary · compare_periods ×2

## Unanswerable (10 prompts)

**Expected: none of these (no endpoint can answer)**

- 1/3 r38: "Which page gets the most link clicks out of all of them?" — wrong runs ended on: top_posts · rank_items ×2
- 0/3 r38A: "Of all my pages, which gets the most link clicks?" — wrong runs ended on: clicks · rank_items ×2, top_posts · rank_items
- 0/3 r38B: "Identify whichever page is the biggest draw for link clicks." — wrong runs ended on: top_posts · rank_items ×3

**Expected: none of these (no endpoint can answer)**

- 1/3 u1: "How much did I actually make from ads last month, after all the network's cuts?" — wrong runs ended on: subscribers · value, report_app_problem

**Expected: none of these (no endpoint can answer)**

- 0/3 u7: "Are readers finishing my 2000-word posts or giving up halfway through?" — wrong runs ended on: insights · list_items, video_plays · compare_items, post · compare_periods
- 0/3 u7A: "Do readers make it through my 2000-word posts, or drop off partway?" — wrong runs ended on: insights · list_items ×2, post · compare_periods
- 1/3 u7B: "See whether people finish my 2000-word articles or abandon them midway." — wrong runs ended on: video_plays · compare_items ×2

**Expected: none of these (no endpoint can answer)**

- 0/3 u10: "how many of my visitors this month are returning readers vs brand new ones" — wrong runs ended on: visits · compare_periods, subscribers · compare_periods ×2
- 0/3 u10A: "This month, what's the split between returning and first-time visitors?" — wrong runs ended on: visits · compare_periods ×3

**Expected: none of these (no endpoint can answer)**

- 0/3 u11B: "Track what gets clicked immediately after someone arrives on my homepage." — wrong runs ended on: clicks · list_items ×3
