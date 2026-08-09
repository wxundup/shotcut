/*
 * The effect catalogue: every entry must be usable, and every renderable
 * effect must produce a filter fragment that changes with its parameters.
 *
 * The renderer mirrors these definitions in PowerShell. This checks the
 * catalogue side is coherent; the render side is verified by exporting.
 */
import QtQuick
import QtTest
import "../EffectCatalogue.js" as Catalogue

Item {
    TestCase {
        name: "EffectCatalogue"

        function test_every_effect_has_a_group_and_parameters() {
            const all = Catalogue.effects
            verify(all.length >= 15, "the catalogue should not shrink silently")
            for (var i = 0; i < all.length; i++) {
                const e = all[i]
                verify(e.name !== undefined && e.name !== "", "effect " + i + " has no name")
                verify(e.group !== undefined && e.group !== "", e.name + " has no group")
                verify(e.params !== undefined && e.params.length > 0,
                       e.name + " has no parameters")
            }
        }

        function test_parameters_have_usable_ranges() {
            const all = Catalogue.effects
            for (var i = 0; i < all.length; i++) {
                const e = all[i]
                for (var j = 0; j < e.params.length; j++) {
                    const p = e.params[j]
                    verify(p.min < p.max, e.name + "/" + p.name + " has an empty range")
                    verify(p.value >= p.min && p.value <= p.max,
                           e.name + "/" + p.name + " defaults outside its own range")
                }
            }
        }

        function test_defaults_round_trip_by_name() {
            const all = Catalogue.effects
            for (var i = 0; i < all.length; i++) {
                const params = Catalogue.defaultParams(all[i].name)
                compare(params.length, all[i].params.length,
                        all[i].name + " lost parameters through defaultParams")
                for (var j = 0; j < params.length; j++)
                    verify(params[j].keyframes !== undefined,
                           "a new parameter must carry a keyframe list")
            }
        }

        function test_unknown_effect_yields_nothing() {
            compare(Catalogue.find("No Such Effect"), null)
            compare(Catalogue.defaultParams("No Such Effect").length, 0)
        }

        // An effect at its defaults should cost nothing in the graph, and
        // moving a parameter should produce a fragment. Without both, an
        // effect can look present and render as a no-op.
        function test_renderable_effects_respond_to_their_parameters() {
            const all = Catalogue.effects
            let checked = 0
            for (var i = 0; i < all.length; i++) {
                const e = all[i]
                if (!e.render || e.geometric || e.audio)
                    continue

                const atDefault = {}
                for (var j = 0; j < e.params.length; j++)
                    atDefault[e.params[j].name] = e.params[j].value

                // Generators draw as soon as they are added — that is what
                // they are for. Everything else is inert until dialled in.
                if (e.group !== "Generate") {
                    compare(e.render(atDefault, e), "",
                            e.name + " renders a filter while at its defaults")
                }

                // Push the first parameter to its extreme.
                const moved = {}
                for (var k = 0; k < e.params.length; k++)
                    moved[e.params[k].name] = e.params[k].value
                const first = e.params[0]
                moved[first.name] = (first.value === first.max) ? first.min : first.max

                const fragment = e.render(moved, e)
                verify(fragment.length > 0,
                       e.name + " renders nothing even with " + first.name + " moved")
                checked++
            }
            verify(checked >= 10, "expected most of the catalogue to be renderable")
        }

        function test_filter_arguments_are_escaped() {
            // A colon or quote in text would otherwise break the filtergraph.
            const escaped = Catalogue.esc("a:b'c,d[e]")
            verify(escaped.indexOf("\\:") !== -1, "colon not escaped")
            verify(escaped.indexOf("\\'") !== -1, "quote not escaped")
            verify(escaped.indexOf("\\,") !== -1, "comma not escaped")
        }
    }
}
