import Testing

/// A question and the catalog leaves that count as a correct choice for it.
struct SelectionCase: CustomTestStringConvertible, Sendable {
    let prompt: String
    /// The first id is the intended leaf and is always among the options offered. Any listed id counts as correct.
    let acceptable: [String]
    /// Identifies a case loaded from a prompt file, such as `1A` for version A of prompt 1.
    let label: String?
    /// The operations that count as correct after an acceptable leaf, for experiments with an operation step.
    let acceptableOperations: [String]

    var target: String { acceptable[0] }
    var testDescription: String { prompt }
    /// `[label] ` for reports, or empty when there's no label.
    var labelPrefix: String { label.map { "[\($0)] " } ?? "" }

    init(_ prompt: String, _ acceptable: String...) {
        self.init(prompt: prompt, acceptable: acceptable, label: nil)
    }

    init(prompt: String, acceptable: [String], label: String?, acceptableOperations: [String] = []) {
        self.prompt = prompt
        self.acceptable = acceptable
        self.label = label
        self.acceptableOperations = acceptableOperations
    }

    /// This case with `acceptable` narrowed to the leaves in `offered`. With none left, no offered leaf can answer
    /// it, and "none of these" is the right ending.
    func restricted(to offered: Set<String>) -> SelectionCase {
        SelectionCase(
            prompt: prompt,
            acceptable: acceptable.filter(offered.contains),
            label: label,
            acceptableOperations: acceptableOperations
        )
    }
}

enum SelectionCases {
    static let all: [SelectionCase] = [
        // Stats
        SelectionCase("How many likes did my posts get on January 13?", "stats_on_day"),
        SelectionCase("How many people visited my site yesterday?", "stats_on_day"),
        SelectionCase("How many views did I get today?", "stats_on_day"),
        SelectionCase("Which of my posts were most popular last month?", "top_posts"),
        SelectionCase("Where is my traffic coming from?", "top_referrers", "views_by_country"),
        SelectionCase("What did people search for to find my blog?", "search_terms"),
        SelectionCase("Show me my views over the past 6 months", "views_over_period"),
        SelectionCase("Which countries do my readers come from?", "views_by_country"),
        // Crosses posts and stats
        SelectionCase("How many likes did my latest post get?", "post_likes"),
        // Posts
        SelectionCase("Show me my drafts", "list_draft_posts", "list_draft_pages"),
        SelectionCase("I want to write a new blog post about my trip", "create_post"),
        SelectionCase("What posts do I have scheduled?", "list_scheduled_posts"),
        SelectionCase("Find my post about sourdough bread", "search_posts"),
        // Comments, crossing posts for the second
        SelectionCase("Are there any comments waiting for me to approve?", "list_pending_comments"),
        SelectionCase("What are people saying on my latest post?", "post_comments"),
        // Media
        SelectionCase("Upload a photo from my camera roll", "upload_media"),
        SelectionCase("How much storage space have I used?", "storage_usage"),
        // Reader
        SelectionCase("Show me new posts from blogs I follow", "following_feed"),
        SelectionCase("Follow the site cooking.blog", "follow_site"),
        SelectionCase("Show me the posts I liked", "liked_posts"),
        // Notifications
        SelectionCase("Do I have any new notifications?", "unread_notifications", "list_notifications"),
        // Site settings
        SelectionCase("Change my site's title to Morning Pages", "change_site_title"),
        SelectionCase("Make my site private", "change_site_privacy"),
        // Plugins and themes
        SelectionCase("Update all my plugins", "update_plugins"),
        SelectionCase("Switch my site to a darker theme", "change_theme"),
        // People
        SelectionCase("Invite my friend to write on my blog", "invite_user"),
        SelectionCase("How many subscribers do I have?", "subscriber_count"),
        // Account
        SelectionCase("I forgot my password and want to change it", "change_password"),
        SelectionCase("Change the app's language to Turkish", "change_interface_language"),
        // Support
        SelectionCase("I'd like to talk to someone from support about a billing problem", "contact_support"),
        SelectionCase("How do I add a contact form to my site?", "search_help_articles")
    ]
}
