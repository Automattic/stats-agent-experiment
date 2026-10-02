import Foundation
import WordPressAPI
import WordPressAPIInternal

extension SiteStats {
    /// The stats calls that rank items which `ranking` can request.
    static let rankingEndpoints: Set<String> = [
        "stats_top_posts", "stats_top_authors", "stats_referrers", "stats_search_terms", "stats_country_views",
        "stats_region_views", "stats_city_views", "stats_clicks", "stats_file_downloads", "stats_video_plays",
        "stats_devices_browser", "stats_devices_platform", "stats_devices_screensize"
    ]

    /// The ranking calls whose server reads the span as a number of days whatever the period: `num` for most, and
    /// `days` for the devices calls, which take no period.
    static let dayCountingEndpoints: Set<String> = [
        "stats_top_posts", "stats_referrers", "stats_country_views", "stats_region_views", "stats_city_views",
        "stats_clicks", "stats_video_plays", "stats_devices_browser", "stats_devices_platform",
        "stats_devices_screensize"
    ]

    struct UnsupportedEndpoint: LocalizedError {
        let id: String

        var errorDescription: String? {
            "The app can't request \(id) yet."
        }
    }

    /// What `endpoint`, one of `rankingEndpoints`, returns for `request`, added up over its periods, highest first and
    /// at most the request's number of items: regions and cities returned more than the `max` sent.
    func ranking(_ endpoint: String, _ request: RankingRequest) async throws -> RankedList {
        let list: RankedList
        switch endpoint {
        case "stats_top_posts": list = try await topPosts(request)
        case "stats_top_authors": list = try await topAuthors(request)
        case "stats_referrers": list = try await referrers(request)
        case "stats_search_terms": list = try await searchTerms(request)
        case "stats_country_views": list = try await countryViews(request)
        case "stats_region_views": list = try await regionViews(request)
        case "stats_city_views": list = try await cityViews(request)
        case "stats_clicks": list = try await clicks(request)
        case "stats_file_downloads": list = try await fileDownloads(request)
        case "stats_video_plays": list = try await videoPlays(request)
        case "stats_devices_browser", "stats_devices_platform", "stats_devices_screensize":
            list = try await devices(endpoint, request)
        default: throw UnsupportedEndpoint(id: endpoint)
        }
        // A total smaller than the listed items is dropped: country views has returned a total of 0 above its listed
        // countries.
        let listed = list.rows.reduce(0) { $0 + $1.value }
        return RankedList(
            metricTitle: list.metricTitle,
            rows: Array(list.rows.sorted { $0.value > $1.value }.prefix(request.maximumItems)),
            total: list.total.flatMap { $0 >= listed ? $0 : nil },
            isPercentage: list.isPercentage
        )
    }

    private func topPosts(_ request: RankingRequest) async throws -> RankedList {
        let params = StatsTopPostsParams(
            period: Self.topPostsPeriod(request.granularity),
            date: request.wpDate,
            max: request.maxItems,
            num: request.num
        )
        let summary = try await client.statsTopPosts()
            .getStatsTopPostsCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data.summary
        return RankedList(
            metricTitle: "Views",
            rows: (summary?.postviews ?? [])
                .map { post in
                    RankedList.Row(
                        name: post.title ?? post.href ?? "Post \(post.id)",
                        value: Int(clamping: post.views ?? 0)
                    )
                },
            total: summary.map { Int(clamping: $0.totalViews) }
        )
    }

    /// The server returns at most 20 authors.
    private func topAuthors(_ request: RankingRequest) async throws -> RankedList {
        let params = StatsTopAuthorsParams(
            period: Self.topAuthorsPeriod(request.granularity),
            date: request.wpDate,
            max: request.maxItems,
            num: request.num
        )
        let authors = try await client.statsTopAuthors()
            .getStatsTopAuthorsCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data.summary?
            .authors
        return RankedList(
            metricTitle: "Views",
            rows: (authors ?? []).map { RankedList.Row(name: $0.name, value: Int(clamping: $0.views)) },
            total: nil
        )
    }

    private func referrers(_ request: RankingRequest) async throws -> RankedList {
        let params = StatsReferrersParams(
            period: Self.referrersPeriod(request.granularity),
            date: request.wpDate,
            max: request.maxItems,
            num: request.num
        )
        let summary = try await client.statsReferrers()
            .getStatsReferrersCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data.summary
        return RankedList(
            metricTitle: "Views",
            rows: (summary?.groups ?? [])
                .map { group in
                    RankedList.Row(
                        name: group.name ?? group.group ?? group.url ?? "Unknown",
                        value: Int(clamping: group.total ?? 0)
                    )
                },
            total: summary.map { Int(clamping: $0.totalViews) }
        )
    }

    private func searchTerms(_ request: RankingRequest) async throws -> RankedList {
        let params = StatsSearchTermsParams(
            period: Self.searchTermsPeriod(request.granularity),
            date: request.wpDate,
            max: request.maxItems,
            num: request.num
        )
        let summary = try await client.statsSearchTerms()
            .getStatsSearchTermsCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data.summary
        return RankedList(
            metricTitle: "Views",
            rows: (summary?.searchTerms ?? [])
                .map { entry in
                    RankedList.Row(name: entry.term ?? "Unknown", value: Int(clamping: entry.views ?? 0))
                },
            total: nil
        )
    }

    private func countryViews(_ request: RankingRequest) async throws -> RankedList {
        let params = StatsCountryViewsParams(
            period: Self.countryViewsPeriod(request.granularity),
            date: request.wpDate,
            max: request.maxItems,
            num: request.num
        )
        let data = try await client.statsCountryViews()
            .getStatsCountryViewsCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data
        return RankedList(
            metricTitle: "Views",
            rows: (data.summary?.views ?? [])
                .map { country in
                    let info = country.countryCode.flatMap { data.countryInfo?[$0] }
                    return RankedList.Row(
                        name: info?.countryFull ?? country.location ?? country.countryCode ?? "Unknown",
                        value: Int(clamping: country.views ?? 0)
                    )
                },
            total: data.summary.map { Int(clamping: $0.totalViews) }
        )
    }

    /// The server forces the period to days.
    private func regionViews(_ request: RankingRequest) async throws -> RankedList {
        let params = StatsRegionViewsParams(period: .day, date: request.wpDate, max: request.maxItems, num: request.num)
        let data = try await client.statsRegionViews()
            .getStatsRegionViewsCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data
        return RankedList(
            metricTitle: "Views",
            rows: (data.summary?.views ?? [])
                .map { region in
                    let country = region.countryCode.flatMap { data.countryInfo?[$0]?.countryFull }
                    return RankedList.Row(
                        name: Self.place(region.location, in: country ?? region.countryCode),
                        value: Int(clamping: region.views ?? 0)
                    )
                },
            total: data.summary.map { Int(clamping: $0.totalViews) }
        )
    }

    /// The server forces the period to days.
    private func cityViews(_ request: RankingRequest) async throws -> RankedList {
        let params = StatsCityViewsParams(period: .day, date: request.wpDate, max: request.maxItems, num: request.num)
        let data = try await client.statsCityViews()
            .getStatsCityViewsCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data
        return RankedList(
            metricTitle: "Views",
            rows: (data.summary?.views ?? [])
                .map { city in
                    let country = city.countryCode.flatMap { data.countryInfo?[$0]?.countryFull }
                    return RankedList.Row(
                        name: Self.place(city.location, in: country ?? city.countryCode),
                        value: Int(clamping: city.views ?? 0)
                    )
                },
            total: data.summary.map { Int(clamping: $0.totalViews) }
        )
    }

    /// The server reads `num` as days whatever the period.
    private func clicks(_ request: RankingRequest) async throws -> RankedList {
        let params = StatsClicksParams(period: .day, date: request.wpDate, max: request.maxItems, num: request.num)
        let summary = try await client.statsClicks()
            .getStatsClicksCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data.summary
        return RankedList(
            metricTitle: "Clicks",
            rows: (summary?.clicks ?? [])
                .map { entry in
                    RankedList.Row(name: entry.name ?? entry.url ?? "Unknown", value: Int(clamping: entry.views ?? 0))
                },
            total: summary.map { Int(clamping: $0.totalClicks) }
        )
    }

    private func fileDownloads(_ request: RankingRequest) async throws -> RankedList {
        let params = StatsFileDownloadsParams(
            period: Self.fileDownloadsPeriod(request.granularity),
            date: request.wpDate,
            max: request.maxItems,
            num: request.num
        )
        let summary = try await client.statsFileDownloads()
            .getStatsFileDownloadsCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data.summary
        return RankedList(
            metricTitle: "Downloads",
            rows: (summary?.files ?? [])
                .map { file in
                    RankedList.Row(
                        name: file.filename ?? file.relativeUrl ?? file.downloadUrl ?? "Unknown",
                        value: Int(clamping: file.downloads ?? 0)
                    )
                },
            total: summary.map { Int(clamping: $0.totalDownloads) }
        )
    }

    /// The server reads `num` as days whatever the period, and returns the list under `days.summary`.
    private func videoPlays(_ request: RankingRequest) async throws -> RankedList {
        let params = StatsVideoPlaysParams(period: .day, date: request.wpDate, max: request.maxItems, num: request.num)
        let summary = try await client.statsVideoPlays()
            .getStatsVideoPlaysCancellation(wpComSiteId: siteID, params: params, context: nil)
            .data.days.summary
        return RankedList(
            metricTitle: "Plays",
            rows: summary.data.map { video in
                RankedList.Row(name: video.title ?? "Video \(video.postId)", value: Int(clamping: video.views ?? 0))
            },
            total: Int(clamping: summary.total.views)
        )
    }

    /// The devices calls take a number of days and no period. Browsers and platforms count views; screen sizes are
    /// percentages of the views of the sizes returned, rounded here to whole percents.
    private func devices(_ endpoint: String, _ request: RankingRequest) async throws -> RankedList {
        let params = StatsDevicesParams(date: request.wpDate, max: request.maxItems, days: request.num)
        let isScreenSize = endpoint == "stats_devices_screensize"
        let values =
            switch endpoint {
            case "stats_devices_browser":
                try await client.statsDevicesBrowser()
                    .getStatsDevicesBrowserCancellation(wpComSiteId: siteID, params: params, context: nil)
                    .data.topValues
            case "stats_devices_platform":
                try await client.statsDevicesPlatform()
                    .getStatsDevicesPlatformCancellation(wpComSiteId: siteID, params: params, context: nil)
                    .data.topValues
            default:
                try await client.statsDevicesScreensize()
                    .getStatsDevicesScreensizeCancellation(wpComSiteId: siteID, params: params, context: nil)
                    .data.topValues
            }
        return RankedList(
            metricTitle: isScreenSize ? "Share of views" : "Views",
            rows: values.map { RankedList.Row(name: $0.key, value: Int($0.value.rounded())) },
            total: nil,
            isPercentage: isScreenSize
        )
    }

    /// A region or city with its country, such as "Ontario, Canada".
    private static func place(_ location: String?, in country: String?) -> String {
        let parts = [location, country].compactMap(\.self)
        return parts.isEmpty ? "Unknown" : parts.joined(separator: ", ")
    }

    // Each ranking call has its own period type with the same cases. Hours aren't among them; they fall back to days.

    private static func topPostsPeriod(_ granularity: DateRangeGranularity) -> StatsTopPostsPeriod {
        switch granularity {
        case .hour, .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }

    private static func topAuthorsPeriod(_ granularity: DateRangeGranularity) -> StatsTopAuthorsPeriod {
        switch granularity {
        case .hour, .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }

    private static func referrersPeriod(_ granularity: DateRangeGranularity) -> StatsReferrersPeriod {
        switch granularity {
        case .hour, .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }

    private static func countryViewsPeriod(_ granularity: DateRangeGranularity) -> StatsCountryViewsPeriod {
        switch granularity {
        case .hour, .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }

    private static func searchTermsPeriod(_ granularity: DateRangeGranularity) -> StatsSearchTermsPeriod {
        switch granularity {
        case .hour, .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }

    private static func fileDownloadsPeriod(_ granularity: DateRangeGranularity) -> StatsFileDownloadsPeriod {
        switch granularity {
        case .hour, .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        }
    }
}

extension RankingRequest {
    fileprivate var wpDate: WpDateString? {
        date.map { WpDateString(value: $0) }
    }

    fileprivate var num: UInt32 {
        UInt32(clamping: periods)
    }

    fileprivate var maxItems: UInt32 {
        UInt32(clamping: maximumItems)
    }
}
