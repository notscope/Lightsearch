import Foundation

extension ConversionUnitCatalog {
    static let length: [ConversionUnitDefinition] = [
        // MARK: - Length
        // The less common historical, typographic, and astronomical
        // units are included because they are useful in real-world searches.
        linearUnit(
            "length.meter", .length, "Meters", "m",
            ["m", "meter", "meters", "metre", "metres"], 1,
            defaultTargetID: "length.foot"
        ),
        linearUnit(
            "length.kilometer", .length, "Kilometers", "km",
            ["km", "kilometer", "kilometers", "kilometre", "kilometres"], 1_000,
            defaultTargetID: "length.mile"
        ),
        linearUnit(
            "length.centimeter", .length, "Centimeters", "cm",
            ["cm", "centimeter", "centimeters", "centimetre", "centimetres"], 0.01,
            defaultTargetID: "length.inch"
        ),
        linearUnit(
            "length.millimeter", .length, "Millimeters", "mm",
            ["mm", "millimeter", "millimeters", "millimetre", "millimetres"], 0.001,
            defaultTargetID: "length.inch"
        ),
        linearUnit(
            "length.micrometer", .length, "Micrometers", "µm",
            ["um", "µm", "micrometer", "micrometers", "micron", "microns"], 0.000001,
            defaultTargetID: "length.nanometer"
        ),
        linearUnit(
            "length.nanometer", .length, "Nanometers", "nm",
            ["nm", "nanometer", "nanometers", "nanometre", "nanometres"], 0.000000001,
            defaultTargetID: "length.micrometer"
        ),
        linearUnit(
            "length.inch", .length, "Inches", "in",
            ["in", "inch", "inches", "\""], 0.0254,
            defaultTargetID: "length.centimeter"
        ),
        linearUnit(
            "length.foot", .length, "Feet", "ft",
            ["ft", "foot", "feet", "'"], 0.3048,
            defaultTargetID: "length.meter"
        ),
        linearUnit(
            "length.yard", .length, "Yards", "yd",
            ["yd", "yard", "yards"], 0.9144,
            defaultTargetID: "length.meter"
        ),
        linearUnit(
            "length.mile", .length, "Miles", "mi",
            ["mi", "mile", "miles", "statute mile", "statute miles"], 1_609.344,
            defaultTargetID: "length.kilometer"
        ),
        linearUnit(
            "length.nauticalMile", .length, "Nautical Miles", "nmi",
            ["nmi", "nautical mile", "nautical miles", "nmile", "sea mile", "sea miles"], 1_852,
            defaultTargetID: "length.kilometer"
        ),
        linearUnit(
            "length.fathom", .length, "Fathoms", "ftm",
            ["ftm", "fathom", "fathoms"], 1.8288,
            defaultTargetID: "length.meter"
        ),
        linearUnit(
            "length.furlong", .length, "Furlongs", "fur",
            ["fur", "furlong", "furlongs"], 201.168,
            defaultTargetID: "length.mile"
        ),
        linearUnit(
            "length.league", .length, "Leagues", "lea",
            ["lea", "league", "leagues"], 4_828.032,
            defaultTargetID: "length.mile"
        ),
        linearUnit(
            "length.chain", .length, "Chains", "ch",
            ["ch", "chain", "chains"], 20.1168,
            defaultTargetID: "length.meter"
        ),
        linearUnit(
            "length.rod", .length, "Rods", "rd",
            ["rd", "rod", "rods", "pole", "poles", "perch", "perches"], 5.0292,
            defaultTargetID: "length.meter"
        ),
        linearUnit(
            "length.link", .length, "Links", "li",
            ["li", "link", "links"], 0.201168,
            defaultTargetID: "length.meter"
        ),
        linearUnit(
            "length.hand", .length, "Hands", "hand",
            ["hand", "hands"], 0.1016,
            defaultTargetID: "length.centimeter"
        ),
        linearUnit(
            "length.cubit", .length, "Cubits", "cubit",
            ["cubit", "cubits"], 0.4572,
            defaultTargetID: "length.meter"
        ),
        linearUnit(
            "length.point", .length, "Points", "pt",
            ["pt", "point", "points", "typographic point"], 0.000352777777778,
            defaultTargetID: "length.millimeter"
        ),
        linearUnit(
            "length.pica", .length, "Picas", "pc",
            ["pica", "picas"], 0.00423333333333,
            defaultTargetID: "length.millimeter", includeSymbol: false
        ),
        linearUnit(
            "length.mil", .length, "Mils", "mil",
            ["mil", "mils", "thou", "thousandth inch"], 0.0000254,
            defaultTargetID: "length.millimeter"
        ),
        linearUnit(
            "length.angstrom", .length, "Angstroms", "Å",
            ["a", "å", "angstrom", "angstroms"], 0.0000000001,
            defaultTargetID: "length.nanometer"
        ),
        linearUnit(
            "length.cable", .length, "Cables", "cable",
            ["cable", "cables", "cable length"], 185.2,
            defaultTargetID: "length.meter"
        ),
        linearUnit(
            "length.astronomicalUnit", .length, "Astronomical Units", "AU",
            ["au", "astronomical unit", "astronomical units"], 149_597_870_700,
            defaultTargetID: "length.kilometer"
        ),
        linearUnit(
            "length.lightYear", .length, "Light-Years", "ly",
            ["ly", "light year", "light years", "light-year", "light-years"], 9.4607304725808e15,
            defaultTargetID: "length.kilometer"
        ),
        linearUnit(
            "length.parsec", .length, "Parsecs", "pc",
            ["parsec", "parsecs"], 3.0856775814913673e16,
            defaultTargetID: "length.lightYear"
        ),

    ]
}
