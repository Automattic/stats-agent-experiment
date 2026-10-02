# Questions the agent gets right in most orders

132 of 183 prompts, right in 2 or 3 of the 3 orders. From the main setup's results, sighted with the operation step: `results/stats-endpoints/sighted-with-operations.txt`, `results/stats-endpoints/stats-paraphrases-round-1/sighted-with-operations.txt`, `results/stats-endpoints/stats-questions-insights-round-1/sighted-with-operations.txt`. Each prompt ran once in each of 3 option orders. A run is right when it ends on an acceptable endpoint with an acceptable operation or, when no endpoint can answer, without an answer. Prompts are grouped by question under its expected answer, the original first and its paraphrases (labels ending in A or B) after it. Endpoint ids are shown without their `stats_` prefix.

## Answerable (97 prompts)

**Expected: visits or summary · value**

- 3/3 r1: "How many views did I get today?"
- 3/3 r1A: "What's my view count for today?"
- 3/3 r1B: "Tally up how many times my site's been viewed today."

**Expected: top_posts · rank_items**

- 2/3 r2: "Which post got the most views this week?" — missed: post · highest_or_lowest_period
- 2/3 r2A: "Which post has the highest view count this week?" — missed: post · compare_periods
- 3/3 r2B: "Name whichever post pulled the most eyes this week."

**Expected: visits or summary · value**

- 3/3 r3: "Yesterday's total views?"
- 3/3 r3A: "What was the full view tally for yesterday?"

**Expected: subscribers · trend**

- 3/3 r4: "Is my subscriber count growing or shrinking lately?"
- 3/3 r4A: "Has my subscriber list been expanding or contracting lately?"
- 3/3 r4B: "Figure out if I'm gaining more subscribers than I'm losing lately, or the reverse."

**Expected: visits · value**

- 2/3 r5: "How many visitors did I have on August 15th?" — missed: summary · value
- 3/3 r5A: "What was my visitor count on August 15th?"
- 3/3 r5B: "Pull up how many people came to my site on August 15th."

**Expected: visits · compare_periods**

- 3/3 r6B: "Am I seeing more or less traffic this month versus last month?"

**Expected: visits · value**

- 3/3 r7: "Give me this week's total number of likes."
- 3/3 r7A: "What's the total like count for this week?"
- 2/3 r7B: "Add up all my likes for this week." — missed: post · value

**Expected: top_posts · rank_items**

- 2/3 r8A: "Which post has done the best, ever?" — missed: post · highest_or_lowest_period
- 3/3 r8B: "Looking across everything I've ever published, name the top performer."

**Expected: visits · value**

- 2/3 r9: "How many comments came in last month?" — missed: summary · value

**Expected: visits or summary · highest_or_lowest_period**

- 2/3 r10: "Which day this week had the most visitors?" — missed: insights · value

**Expected: subscribers or summary · value**

- 3/3 r11: "What's my current subscriber count?"
- 3/3 r11A: "How many subscribers do I have right now?"
- 3/3 r11B: "Pull up my current subscriber number."

**Expected: visits or summary · compare_periods or value**

- 3/3 r12: "How does today's traffic compare to yesterday's?"
- 3/3 r12A: "Compare today's traffic to yesterday's."
- 2/3 r12B: "Am I getting more visits today than yesterday?" — missed: visits · trend

**Expected: summary or subscribers · value**

- 3/3 r13: "Follower count right now?"
- 3/3 r13A: "What's my follower total at the moment?"
- 3/3 r13B: "Check how many followers I currently have."

**Expected: visits · trend**

- 3/3 r14: "What's the trend in comments been over the last three months?"
- 3/3 r14A: "How have comments trended over the past three months?"

**Expected: summary or visits · value**

- 3/3 r15: "What's my all-time total pageview count?"
- 3/3 r15A: "How many total pageviews have I gotten, all-time?"
- 3/3 r15B: "Give me my lifetime pageview total."

**Expected: visits · value**

- 3/3 r17: "How many people visited my site last week?"
- 3/3 r17A: "What was last week's visitor total?"
- 3/3 r17B: "Count how many people visited last week."

**Expected: country_views · list_items or rank_items**

- 3/3 r19: "Which countries did my visitors come from this month?"
- 3/3 r19A: "What countries were this month's visitors from?"
- 3/3 r19B: "Break down this month's visitors by country of origin."

**Expected: top_posts · rank_items**

- 3/3 r20: "Rank my top five posts by views this month."
- 3/3 r20A: "List this month's five highest-viewed posts, ranked."
- 3/3 r20B: "What are my top five posts by views so far this month?"

**Expected: search_terms · list_items or rank_items**

- 3/3 r21: "What are people searching for to find my blog this week?"
- 2/3 r21A: "What search terms are leading people to my blog this week?" — missed: search_terms · compare_periods
- 3/3 r21B: "Dig up what people are typing into search to land on my blog this week."

**Expected: emails_summary · trend**

- 2/3 r22: "Is my newsletter open rate improving or getting worse?" — missed: none of these
- 3/3 r22A: "Has my newsletter open rate been getting better or worse lately?"

**Expected: file_downloads · value**

- 2/3 r23: "How many times was my podcast episode downloaded yesterday?" — missed: none of these
- 2/3 r23A: "What was yesterday's download count for my podcast episode?" — missed: file_downloads · list_items
- 3/3 r23B: "Total yesterday's downloads on my podcast episode."

**Expected: visits · compare_periods**

- 3/3 r24: "What changed in my traffic this week versus last week?"

**Expected: video_plays · value**

- 3/3 r25: "How many plays did my latest video get this month?"
- 2/3 r25A: "What's this month's play count for my newest video?" — missed: video_plays · compare_periods
- 3/3 r25B: "Count up the plays my latest video got this month."

**Expected: referrers · rank_items**

- 3/3 r26: "Which referrer sends me the most clicks these days?"
- 3/3 r26A: "What's my top referring source for clicks lately?"

**Expected: devices_screensize or devices_platform · list_items or compare_items**

- 3/3 r27: "What devices is my traffic coming from today?"
- 2/3 r27A: "Segment today's traffic by device type." — missed: devices_browser · compare_items
- 3/3 r27B: "What kind of devices are people using to visit today?"

**Expected: referrers or search_terms · compare_periods or trend**

- 3/3 r28: "Feels like more people are finding me through search lately — is that actually true compared to a few months ago?"
- 3/3 r28A: "Search traffic feels like it's up lately — is that true versus a few months ago?"
- 3/3 r28B: "I think I'm getting more search visitors than a few months back — confirm that."

**Expected: emails_summary · value**

- 2/3 r29: "How many people opened my last email newsletter?" — missed: none of these
- 3/3 r29B: "Total how many people opened my last email newsletter."

**Expected: top_posts · rank_items**

- 3/3 r30: "What's my worst performing post this year?"
- 2/3 r30B: "Call out this year's weakest performing post." — missed: none of these

**Expected: subscribers · trend**

- 3/3 r31: "How has my follower growth looked over the last six months?"
- 2/3 r31A: "What's my follower growth trend been over the past six months?" — missed: none of these
- 2/3 r31B: "Walk me through how my followers have grown over the last six months." — missed: summary · trend

**Expected: tags · rank_items**

- 3/3 r32: "Which tags are getting the most engagement lately?"
- 2/3 r32A: "What tags are seeing the most engagement lately?" — missed: tags · list_items
- 3/3 r32B: "Pin down which tags are getting the most engagement these days."

**Expected: top_authors · rank_items**

- 2/3 r35: "Who's my most popular author this quarter?" — missed: top_authors · compare_periods
- 3/3 r35A: "Which author is most popular this quarter?"
- 3/3 r35B: "Flag whichever author's posts are getting the most traction this quarter."

**Expected: video_plays · compare_periods**

- 3/3 r36: "Is video engagement up or down compared to last month?"
- 3/3 r36A: "Has video engagement gone up or down since last month?"
- 3/3 r36B: "See if people are engaging with my videos more or less than last month."

**Expected: subscribers · trend or highest_or_lowest_period**

- 2/3 r37: "When did my subscribers start dropping off?" — missed: none of these

**Expected: devices_screensize · compare_items**

- 2/3 r39B: "This month, am I getting more visits from phones or from desktop?" — missed: devices_platform · compare_items

**Expected: visits · compare_periods or trend**

- 2/3 r40B: "This month looks unusual — spell out what's changed relative to my normal baseline." — missed: summary · compare_periods

**Expected: devices_screensize · compare_items**

- 3/3 u12: "is my audience mostly on their phones skimming, or on desktop actually reading"
- 3/3 u12B: "Work out whether readers are mostly glancing on phones or giving real attention on desktop."

**Expected: visits · compare_periods**

- 3/3 session-4: "Did I get more likes this month than I did last month?"
- 3/3 session-4A: "Are this month's likes higher than last month's?"
- 2/3 session-4B: "Compare my like counts between this month and last month." — missed: post · compare_periods

**Expected: insights · value or list_items or rank_items**

- 3/3 i1: "What time of day tends to bring in the most readers?"

**Expected: insights · value or list_items or rank_items**

- 2/3 i2: "Is there one weekday that consistently outperforms the rest for traffic?" — missed: summary · trend

**Expected: insights · value or list_items or rank_items**

- 3/3 i3: "Do I see more visitors in the morning or later at night?"

**Expected: insights · value or list_items or rank_items**

- 3/3 i4: "Saturday versus Tuesday — which one usually wins for me?"

**Expected: insights · value or list_items or rank_items**

- 3/3 i5: "Around what hour does my site tend to spike?"

**Expected: insights · value or list_items or rank_items**

- 3/3 i6: "Do I do better on weekdays or weekends overall?"

**Expected: insights · value or list_items or rank_items**

- 2/3 i9: "Roughly how many words did I put down across everything I wrote last year?" — missed: post · value

**Expected: insights · value or list_items or rank_items**

- 2/3 i10: "How does what I've published this year stack up against five years back?" — missed: summary · compare_periods

## Unanswerable (35 prompts)

**Expected: none of these (no endpoint can answer)**

- 3/3 u1A: "What was my net ad revenue last month, after the ad network's cut?"
- 3/3 u1B: "Tell me my actual ad earnings from last month, once the network's fees are taken out."

**Expected: none of these (no endpoint can answer)**

- 3/3 u2: "what's the average time someone spends actually reading a post, not just having the tab open"
- 3/3 u2A: "On average, how long do people actually spend reading a post, not just leaving the tab open?"
- 3/3 u2B: "Figure out the real average reading time per post, excluding idle open tabs."

**Expected: none of these (no endpoint can answer)**

- 3/3 u3: "Who are my readers really — age, gender, that kind of thing?"
- 3/3 u3A: "Profile my readers by age, gender, and similar details."
- 3/3 u3B: "What does my audience look like demographically — age, gender, and so on?"

**Expected: none of these (no endpoint can answer)**

- 3/3 u4: "Do people who click in from Pinterest stick around or bounce in five seconds?"
- 3/3 u4A: "Do Pinterest visitors stick around, or leave within five seconds?"
- 2/3 u4B: "Check whether people clicking in from Pinterest stay engaged or bail almost immediately." — missed: referrers · compare_items

**Expected: none of these (no endpoint can answer)**

- 3/3 u5: "what percentage of visitors turn into email subscribers"
- 3/3 u5A: "What share of visitors end up as email subscribers?"
- 3/3 u5B: "Work out the conversion rate from visitor to email subscriber."

**Expected: none of these (no endpoint can answer)**

- 3/3 u6: "how much affiliate income did the last quarter bring in total"
- 3/3 u6A: "What was my total affiliate income last quarter?"
- 3/3 u6B: "Add up everything earned from affiliates over the last quarter."

**Expected: none of these (no endpoint can answer)**

- 3/3 u8: "Once I subtract hosting, plugins, and tools, am I actually profitable this year?"
- 3/3 u8A: "After deducting hosting, plugins, and tools, is this year actually profitable?"
- 3/3 u8B: "Factor out hosting, plugin, and tool costs — am I in the black this year?"

**Expected: none of these (no endpoint can answer)**

- 3/3 u9: "which specific posts are driving the most newsletter signups"
- 3/3 u9A: "Which exact posts generate the most newsletter signups?"
- 3/3 u9B: "Point out the specific articles responsible for most of my newsletter signups."

**Expected: none of these (no endpoint can answer)**

- 3/3 u10B: "Split this month's traffic into new visitors versus people coming back."

**Expected: none of these (no endpoint can answer)**

- 2/3 u11: "What do people click on right after they land on my homepage?" — missed: clicks · list_items
- 3/3 u11A: "After landing on my homepage, what do visitors click next?"

**Expected: none of these (no endpoint can answer)**

- 3/3 u13: "What's the lifetime value of a subscriber who found me through search vs social?"
- 3/3 u13A: "Compare the lifetime value of subscribers from search against those from social."
- 3/3 u13B: "Is a subscriber who found me through search worth more, long-term, than one from social?"

**Expected: none of these (no endpoint can answer)**

- 3/3 u14: "do people who leave comments end up buying anything down the line"
- 3/3 u14A: "Do commenters eventually become paying customers later on?"
- 3/3 u14B: "Check whether leaving a comment correlates with a future purchase."

**Expected: none of these (no endpoint can answer)**

- 3/3 u15: "roughly how many of my readers are running ad blockers"
- 3/3 u15A: "Estimate the share of readers using ad blockers."
- 3/3 u15B: "Roughly what fraction of my visitors have an ad blocker on?"
