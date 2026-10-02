/// A node in the catalog tree. Leaves have no children.
public struct CatalogNode: Sendable {
    public let id: String
    public let description: String
    public let children: [CatalogNode]

    static func leaf(_ id: String, _ description: String) -> CatalogNode {
        CatalogNode(id: id, description: description, children: [])
    }

    static func branch(_ id: String, _ description: String, _ children: [CatalogNode]) -> CatalogNode {
        CatalogNode(id: id, description: description, children: children)
    }

    public var option: OptionSelector.Option {
        OptionSelector.Option(id: id, description: description)
    }

    /// Whether this node is, or has below it, a leaf with one of `ids`.
    public func contains(anyOf ids: [String]) -> Bool {
        children.isEmpty ? ids.contains(id) : children.contains { $0.contains(anyOf: ids) }
    }
}

/// Things a person might ask the WordPress app for, split by feature area.
///
/// A leaf can sit under more than one branch. Shared leaves are defined once below and reused.
public enum Catalog {
    static let postLikes = CatalogNode.leaf("post_likes", "Show how many likes a specific post got.")
    static let postViews = CatalogNode.leaf("post_views", "Show how many views a specific post got.")
    static let postComments = CatalogNode.leaf("post_comments", "Show the comments on a specific post.")
    static let subscriberCount = CatalogNode.leaf("subscriber_count", "Show how many subscribers the site has.")
    static let storageUsage = CatalogNode.leaf("storage_usage", "Show how much storage space the site uses.")

    public static let root: [CatalogNode] = [
        .branch(
            "posts",
            "Blog posts on the site: published, draft, scheduled and trashed posts, writing a new post, finding posts"
                + " by words, tag or category, and a post's likes, views and comments.",
            [
                .leaf("list_published_posts", "List posts that are published on the site."),
                .leaf("list_draft_posts", "List draft posts that haven't been published yet."),
                .leaf("list_scheduled_posts", "List posts scheduled to publish in the future."),
                .leaf("list_trashed_posts", "List posts in the trash."),
                .leaf("search_posts", "Find the site's posts that contain given words."),
                .leaf("create_post", "Start writing a new post."),
                .leaf("latest_post", "Show the most recently published post."),
                .leaf("posts_by_tag", "List the site's posts that have a given tag."),
                .leaf("posts_by_category", "List the site's posts in a given category."),
                postLikes,
                postViews,
                postComments
            ]
        ),
        .branch(
            "pages",
            "Static pages on the site such as About or Contact: published and draft pages, writing a new page, finding"
                + " pages, and choosing the homepage.",
            [
                .leaf("list_pages", "List the site's published pages."),
                .leaf("list_draft_pages", "List draft pages that haven't been published yet."),
                .leaf("create_page", "Start writing a new page."),
                .leaf("search_pages", "Find the site's pages that contain given words."),
                .leaf("set_homepage", "Choose which page is the site's homepage.")
            ]
        ),
        .branch(
            "comments",
            "Comments visitors leave on the site: pending, approved and spam comments, approving and replying to them,"
                + " comments by a given person, and the comments on a specific post.",
            [
                .leaf("list_pending_comments", "List comments waiting for approval."),
                .leaf("list_approved_comments", "List approved comments."),
                .leaf("list_spam_comments", "List comments marked as spam."),
                .leaf("approve_comment", "Approve a pending comment."),
                .leaf("reply_to_comment", "Reply to a comment."),
                .leaf("comments_by_author", "List comments left by a given person."),
                postComments
            ]
        ),
        .branch(
            "media",
            "The site's media library: images, videos and files, uploading and finding media, and the storage space"
                + " the site uses.",
            [
                .leaf("list_media", "List everything in the media library."),
                .leaf("list_images", "List images in the media library."),
                .leaf("list_videos", "List videos in the media library."),
                .leaf("upload_media", "Upload a photo, video or file to the media library."),
                .leaf("search_media", "Find media by file name or title."),
                storageUsage
            ]
        ),
        .branch(
            "stats",
            "Statistics about the site's audience and traffic: views, visitors, likes and comments on a day or over"
                + " time, all-time totals, top posts and authors, referrers, search terms, countries, devices, clicks,"
                + " file downloads, video plays, and the subscriber count.",
            [
                .leaf("stats_on_day", "Show how many views, visitors, likes or comments the site got on a given day."),
                .leaf("views_over_period", "Show the site's views across a range of days, weeks, months or years."),
                .leaf("all_time_stats", "Show all-time totals for views, visitors and posts."),
                .leaf("top_posts", "List the most viewed posts and pages for a period."),
                .leaf("top_authors", "List the authors whose posts got the most views."),
                .leaf("top_referrers", "List the websites that sent visitors to the site."),
                .leaf("search_terms", "List the search terms people used to find the site."),
                .leaf("views_by_country", "Show the site's views broken down by country."),
                .leaf("visitor_devices", "Show which kinds of devices visitors used."),
                .leaf("outbound_clicks", "List the links on the site that visitors clicked."),
                .leaf("file_downloads", "List the files visitors downloaded from the site."),
                .leaf("video_plays", "Show how many times the site's videos were played."),
                postLikes,
                postViews,
                subscriberCount
            ]
        ),
        .branch(
            "reader",
            "Reading other people's sites: the feed of sites you follow, following and unfollowing sites, posts you"
                + " saved or liked, and discovering or searching posts across WordPress.",
            [
                .leaf("following_feed", "Show recent posts from the sites you follow."),
                .leaf("list_followed_sites", "List the sites you follow."),
                .leaf("follow_site", "Start following a site."),
                .leaf("unfollow_site", "Stop following a site."),
                .leaf("saved_posts", "Show posts you saved to read later."),
                .leaf("liked_posts", "Show posts you liked on other sites."),
                .leaf("discover_posts", "Show recommended posts from across WordPress."),
                .leaf("search_reader", "Search posts from sites across WordPress."),
                .leaf("reader_tag_feed", "Show posts from sites across WordPress with a given tag.")
            ]
        ),
        .branch(
            "notifications",
            "Your notifications: recent and unread notifications, marking them as read, and choosing which ones you"
                + " receive.",
            [
                .leaf("list_notifications", "Show recent notifications."),
                .leaf("unread_notifications", "Show notifications you haven't read."),
                .leaf("mark_notifications_read", "Mark all notifications as read."),
                .leaf("notification_settings", "Change which notifications you receive.")
            ]
        ),
        .branch(
            "site_settings",
            "The site's settings: title, tagline, icon, language, timezone, privacy, domains, plan, and the storage"
                + " space the site uses.",
            [
                .leaf("change_site_title", "Change the site's title."),
                .leaf("change_site_tagline", "Change the site's tagline."),
                .leaf("change_site_icon", "Change the site's icon."),
                .leaf("change_site_language", "Change the language the site is written in."),
                .leaf("change_site_timezone", "Change the site's timezone."),
                .leaf("change_site_privacy", "Make the site public, private or coming soon."),
                .leaf("list_domains", "List the site's domains."),
                .leaf("add_domain", "Add or buy a domain for the site."),
                .leaf("current_plan", "Show the site's current plan."),
                storageUsage
            ]
        ),
        .branch(
            "plugins_and_themes",
            "Plugins and themes: installed plugins, installing, updating and turning off plugins, and the site's"
                + " active theme and switching it.",
            [
                .leaf("list_plugins", "List installed plugins."),
                .leaf("install_plugin", "Find and install a new plugin."),
                .leaf("update_plugins", "Update plugins that have updates available."),
                .leaf("deactivate_plugin", "Turn off an installed plugin."),
                .leaf("current_theme", "Show the site's active theme."),
                .leaf("change_theme", "Switch the site to a different theme.")
            ]
        ),
        .branch(
            "people",
            "People connected to the site: users who manage or write for it, inviting and removing them, their roles,"
                + " and the site's subscribers and subscriber count.",
            [
                .leaf("list_users", "List the people who can manage the site."),
                .leaf("invite_user", "Invite someone to help manage or write for the site."),
                .leaf("change_user_role", "Change a person's role on the site."),
                .leaf("remove_user", "Remove a person from the site."),
                .leaf("list_subscribers", "List the site's subscribers."),
                subscriberCount
            ]
        ),
        .branch(
            "account",
            "Your WordPress.com account: email address, password, display name, the language the app is shown in,"
                + " two-step authentication, purchases, and closing the account.",
            [
                .leaf("change_email", "Change your account's email address."),
                .leaf("change_password", "Change your account's password."),
                .leaf("change_display_name", "Change the name shown on your public profile."),
                .leaf("change_interface_language", "Change the language the app is shown in."),
                .leaf("two_step_authentication", "Turn two-step authentication on or off."),
                .leaf("list_purchases", "Show your purchases and subscriptions."),
                .leaf("close_account", "Close your WordPress.com account.")
            ]
        ),
        .branch(
            "support",
            "Getting help: contacting a human at support, your open support requests, help articles on how to do"
                + " something, and reporting problems with the app.",
            [
                .leaf("contact_support", "Open a support request with a human."),
                .leaf("list_support_requests", "Show your open support requests."),
                .leaf("search_help_articles", "Search WordPress help articles for how to do something."),
                .leaf("report_app_problem", "Report a problem with the app.")
            ]
        )
    ]

    /// Every leaf in the tree, each id listed once, in tree order.
    public static let leaves: [OptionSelector.Option] = leaves(of: root)

    /// Every leaf under `nodes`, each id listed once, in tree order.
    public static func leaves(of nodes: [CatalogNode]) -> [OptionSelector.Option] {
        var seen: Set<String> = []
        var result: [OptionSelector.Option] = []
        func visit(_ node: CatalogNode) {
            if node.children.isEmpty {
                if seen.insert(node.id).inserted {
                    result.append(OptionSelector.Option(id: node.id, description: node.description))
                }
            } else {
                node.children.forEach(visit)
            }
        }
        nodes.forEach(visit)
        return result
    }
}
