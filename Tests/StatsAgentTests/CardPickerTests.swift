import Testing

@testable import StatsAgent

/// Which stats calls become cards, from the single pick and the list. No model calls.
struct CardPickerTests {
    static let none = CatalogNavigator.noneOfThese.id

    static func step(_ chosen: String...) -> CardPicker.Step {
        CardPicker.Step(kind: "endpoint", offered: [], chosen: chosen, duration: .zero)
    }

    @Test func singlePickOfNoneShowsNoCards() {
        let cards = CardPicker.cardEndpoints(single: Self.step(Self.none), list: Self.step("stats_visits"))
        #expect(cards.isEmpty)
    }

    @Test func listDropsRepeatsAndNone() {
        let cards = CardPicker.cardEndpoints(
            single: Self.step("stats_summary"),
            list: Self.step("stats_visits", Self.none, "stats_visits", "stats_referrers")
        )
        #expect(cards.map(\.id) == ["stats_visits", "stats_referrers"])
    }

    @Test func listWithoutCallsFallsBackToSinglePick() {
        let cards = CardPicker.cardEndpoints(single: Self.step("stats_summary"), list: Self.step(Self.none))
        #expect(cards.map(\.id) == ["stats_summary"])
    }
}
