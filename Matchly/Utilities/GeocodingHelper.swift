//
//  GeocodingHelper.swift
//  Matchly
//
//  Modern geocoding helper using MapKit's MKLocalSearch API
//

import Foundation
import MapKit
import CoreLocation

/// Modern geocoding helper that uses MapKit's MKLocalSearch API
/// This is the recommended approach for iOS 13+ and eliminates CLGeocoder deprecation warnings
enum GeocodingHelper {
    /// Geocode an address string to a CLLocation
    /// - Parameter addressString: The address to geocode (e.g., "123 Main St, New York, NY")
    /// - Returns: A CLLocation with the coordinates of the address
    /// - Throws: An error if geocoding fails
    static func geocodeAddress(_ addressString: String, expectedState: String? = nil) async throws -> CLLocation {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = addressString
        request.resultTypes = [.address, .pointOfInterest]

        if let stateAbbrev = expectedState.flatMap({ normalizedState($0) }),
           let region = searchRegion(forState: stateAbbrev) {
            request.region = region
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let mapItem = response.mapItems.first else {
            throw GeocodingError.noLocationFound
        }

        let location = mapItem.location
        let coordinate = location.coordinate

        if let stateAbbrev = expectedState.flatMap({ normalizedState($0) }),
           !isPlausible(coordinate, forState: stateAbbrev) {
            throw GeocodingError.noLocationFound
        }

        return location
    }

    /// Resolve a program pin using the same query string as external Maps directions.
    static func coordinate(for program: Program) async -> CLLocationCoordinate2D {
        let resolved = AddressFormatter.resolved(
            hospital: program.hospital,
            address: program.address,
            city: program.city,
            state: program.state,
            accreditationID: program.accreditationID
        )
        let query = AddressFormatter.geocodingQuery(for: program)
        let expectedState = resolved.state

        if let cached = await coordinateCache.lookup(query) {
            return cached
        }

        do {
            let location = try await geocodeAddress(query, expectedState: expectedState)
            let coordinate = location.coordinate
            await coordinateCache.store(coordinate, for: query)
            return coordinate
        } catch {
            return fallbackCoordinate(for: program)
        }
    }

    /// Synchronous city/state fallback when geocoding is unavailable.
    static func fallbackCoordinate(for program: Program) -> CLLocationCoordinate2D {
        let resolved = AddressFormatter.resolved(
            hospital: program.hospital,
            address: program.address,
            city: program.city,
            state: program.state,
            accreditationID: program.accreditationID
        )
        if !resolved.city.isEmpty && !resolved.state.isEmpty {
            return coordinate(for: resolved.city, state: resolved.state)
        }
        if !program.state.isEmpty {
            return coordinate(for: program.state)
        }
        return defaultUSCenter
    }

    static func fallbackCoordinate(for snapshot: CoupleProgramSnapshot) -> CLLocationCoordinate2D {
        if !snapshot.city.isEmpty && !snapshot.state.isEmpty {
            return coordinate(for: snapshot.city, state: snapshot.state)
        }
        if !snapshot.state.isEmpty {
            return coordinate(for: snapshot.state)
        }
        return defaultUSCenter
    }

    /// Fast synchronous distance estimate using city/state lookup tables.
    static func approximateDistanceInMiles(between a: CoupleProgramSnapshot, and b: CoupleProgramSnapshot) -> Double {
        let loc1 = CLLocation(latitude: fallbackCoordinate(for: a).latitude, longitude: fallbackCoordinate(for: a).longitude)
        let loc2 = CLLocation(latitude: fallbackCoordinate(for: b).latitude, longitude: fallbackCoordinate(for: b).longitude)
        return loc1.distance(from: loc2) / 1609.344
    }

    private static let coordinateCache = CoordinateCache()

    private actor CoordinateCache {
        private var storage: [String: CLLocationCoordinate2D] = [:]

        func lookup(_ query: String) -> CLLocationCoordinate2D? {
            storage[query]
        }

        func store(_ coordinate: CLLocationCoordinate2D, for query: String) {
            storage[query] = coordinate
        }
    }
    
    // MARK: - Fallback Coordinate Lookups
    
    /// Get coordinate for address, city, and state (synchronous fallback)
    /// Note: The address parameter is currently ignored; this method uses city/state lookup
    /// For actual address geocoding, use the async `geocodeAddress(_:)` method
    static func coordinate(for address: String, city: String, state: String) -> CLLocationCoordinate2D {
        let resolvedCity = city.trimmingCharacters(in: .whitespaces)
        let cityKey = resolvedCity.lowercased()
        if let cityCoords = majorCities[cityKey] {
            return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
        }
        return coordinate(for: resolvedCity, state: state)
    }
    
    /// Get coordinate for city and state (synchronous fallback)
    static func coordinate(for city: String, state: String) -> CLLocationCoordinate2D {
        let stateAbbrev = normalizedState(state)
        let cityKey = city.lowercased().trimmingCharacters(in: .whitespaces)

        if let cityCoords = majorCities[cityKey] {
            return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
        }

        // Try with state disambiguation for cities with same name
        if cityKey == "springfield" {
            if stateAbbrev == "MA", let cityCoords = majorCities["springfield ma"] {
                return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
            }
            if stateAbbrev == "MO", let cityCoords = majorCities["springfield mo"] {
                return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
            }
        }

        if cityKey == "rochester" {
            if stateAbbrev == "NY", let cityCoords = majorCities["rochester"] {
                return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
            }
            if stateAbbrev == "MN", let cityCoords = majorCities["rochester mn"] {
                return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
            }
        }

        if !stateAbbrev.isEmpty {
            return coordinate(for: stateAbbrev)
        }

        return defaultUSCenter
    }

    /// Get coordinate for state only
    static func coordinate(for state: String) -> CLLocationCoordinate2D {
        let stateAbbrev = normalizedState(state)
        if let coords = USState.centers[stateAbbrev] {
            return CLLocationCoordinate2D(latitude: coords.lat, longitude: coords.lon)
        }

        return defaultUSCenter
    }

    private static let defaultUSCenter = CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795)

    private static func normalizedState(_ state: String) -> String {
        USState.abbreviation(for: state)
    }

    private static func searchRegion(forState stateAbbrev: String) -> MKCoordinateRegion? {
        guard let center = USState.centers[stateAbbrev] else { return nil }
        let span: Double
        switch stateAbbrev {
        case "AK": span = 18
        case "TX", "CA", "MT": span = 10
        default: span = 6
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: center.lat, longitude: center.lon),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }

    private static func isPlausible(_ coordinate: CLLocationCoordinate2D, forState stateAbbrev: String) -> Bool {
        guard let center = USState.centers[stateAbbrev] else { return true }
        let centerLocation = CLLocation(latitude: center.lat, longitude: center.lon)
        let candidate = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let miles = centerLocation.distance(from: candidate) / 1609.344
        let limit: Double
        switch stateAbbrev {
        case "AK": limit = 1_200
        case "TX", "CA", "MT": limit = 650
        default: limit = 450
        }
        return miles <= limit
    }
    
    /// Major city coordinates lookup.
    /// Built once and cached (was previously a computed property that rebuilt
    /// the entire dictionary on every access, a hot path for map views).
    static let majorCities: [String: (lat: Double, lon: Double)] = {
        var cities: [String: (lat: Double, lon: Double)] = [:]
        
        // Florida
        cities["orlando"] = (28.5383, -81.3792)
        cities["kissimmee"] = (28.2920, -81.4076)
        cities["miami"] = (25.7617, -80.1918)
        cities["tampa"] = (27.9506, -82.4572)
        cities["jacksonville"] = (30.3322, -81.6557)
        cities["tallahassee"] = (30.4518, -84.2807)
        cities["fort lauderdale"] = (26.1224, -80.1373)
        cities["west palm beach"] = (26.7153, -80.0534)
        cities["pensacola"] = (30.4213, -87.2169)
        cities["sarasota"] = (27.3364, -82.5307)
        cities["gainesville"] = (29.6516, -82.3248)
        cities["clearwater"] = (27.9659, -82.8001)
        cities["st. petersburg"] = (27.7676, -82.6403)
        cities["aventura"] = (25.9565, -80.1392)
        cities["brandon"] = (27.9378, -82.2859)
        cities["boynton beach"] = (26.5256, -80.0664)
        cities["boca raton"] = (26.3683, -80.1289)
        cities["naples"] = (26.1420, -81.7948)
        cities["ocala"] = (29.1872, -82.1401)
        cities["lakeland"] = (28.0395, -81.9498)
        cities["fort myers"] = (26.6406, -81.8723)
        cities["hollywood"] = (26.0112, -80.1495)
        cities["coral gables"] = (25.7215, -80.2684)
        cities["hialeah"] = (25.8576, -80.2781)
        cities["palm beach gardens"] = (26.8234, -80.1387)
        
        // Louisiana
        cities["baton rouge"] = (30.4515, -91.1871)
        cities["new orleans"] = (29.9511, -90.0715)
        cities["lafayette"] = (30.2241, -92.0198)
        cities["shreveport"] = (32.5252, -93.7502)
        cities["metairie"] = (29.9841, -90.1526)
        cities["lake charles"] = (30.2266, -93.2174)
        cities["monroe"] = (32.5093, -92.1193)
        cities["alexandria"] = (31.3113, -92.4451)
        cities["houma"] = (29.5958, -90.7195)
        
        // California
        cities["los angeles"] = (34.0522, -118.2437)
        cities["san francisco"] = (37.7749, -122.4194)
        cities["san diego"] = (32.7157, -117.1611)
        cities["sacramento"] = (38.5816, -121.4944)
        cities["san jose"] = (37.3382, -121.8863)
        cities["oakland"] = (37.8044, -122.2711)
        cities["fresno"] = (36.7378, -119.7871)
        cities["long beach"] = (33.7701, -118.1937)
        cities["anaheim"] = (33.8366, -117.9143)
        
        // New York
        cities["new york"] = (40.7128, -74.0060)
        cities["buffalo"] = (42.8864, -78.8784)
        cities["rochester"] = (43.1566, -77.6088)
        cities["albany"] = (42.6526, -73.7562)
        cities["syracuse"] = (43.0481, -76.1474)
        cities["yonkers"] = (40.9312, -73.8988)
        
        // Texas
        cities["houston"] = (29.7604, -95.3698)
        cities["dallas"] = (32.7767, -96.7970)
        cities["austin"] = (30.2672, -97.7431)
        cities["san antonio"] = (29.4241, -98.4936)
        cities["fort worth"] = (32.7555, -97.3308)
        cities["el paso"] = (31.7619, -106.4850)
        
        // Illinois
        cities["chicago"] = (41.8781, -87.6298)
        cities["peoria"] = (40.6936, -89.5890)
        cities["rockford"] = (42.2711, -89.0940)
        
        // Pennsylvania
        cities["philadelphia"] = (39.9526, -75.1652)
        cities["pittsburgh"] = (40.4406, -79.9959)
        cities["allentown"] = (40.6084, -75.4902)
        
        // Ohio
        cities["columbus"] = (39.9612, -82.9988)
        cities["cleveland"] = (41.4993, -81.6944)
        cities["cincinnati"] = (39.1031, -84.5120)
        
        // Michigan
        cities["detroit"] = (42.3314, -83.0458)
        cities["grand rapids"] = (42.9634, -85.6681)
        cities["ann arbor"] = (42.2808, -83.7430)
        
        // Massachusetts
        cities["boston"] = (42.3601, -71.0589)
        cities["worcester"] = (42.2626, -71.8023)
        cities["springfield ma"] = (42.1015, -72.5898) // Disambiguate from MO
        
        // Arizona
        cities["phoenix"] = (33.4484, -112.0740)
        cities["tucson"] = (32.2226, -110.9747)
        cities["scottsdale"] = (33.4942, -111.9261)
        
        // Georgia
        cities["atlanta"] = (33.7490, -84.3880)
        cities["augusta"] = (33.4735, -82.0105)
        cities["savannah"] = (32.0809, -81.0912)
        
        // North Carolina
        cities["charlotte"] = (35.2271, -80.8431)
        cities["raleigh"] = (35.7796, -78.6382)
        cities["durham"] = (35.9940, -78.8986)
        
        // Washington
        cities["seattle"] = (47.6062, -122.3321)
        cities["spokane"] = (47.6588, -117.4260)
        cities["tacoma"] = (47.2529, -122.4443)
        
        // Colorado
        cities["denver"] = (39.7392, -104.9903)
        cities["colorado springs"] = (38.8339, -104.8214)
        cities["aurora"] = (39.7294, -104.8319)
        
        // Maryland
        cities["baltimore"] = (39.2904, -76.6122)
        cities["annapolis"] = (38.9784, -76.4922)
        cities["frederick"] = (39.4143, -77.4105)
        
        // Tennessee
        cities["nashville"] = (36.1627, -86.7816)
        cities["memphis"] = (35.1495, -90.0490)
        cities["knoxville"] = (35.9606, -83.9207)
        
        // Missouri
        cities["kansas city"] = (39.0997, -94.5786)
        cities["st. louis"] = (38.6270, -90.1994)
        cities["springfield mo"] = (37.2089, -93.2923) // Disambiguate from MA
        
        // Wisconsin
        cities["milwaukee"] = (43.0389, -87.9065)
        cities["madison"] = (43.0731, -89.4012)
        cities["green bay"] = (44.5192, -88.0198)
        
        // Minnesota
        cities["minneapolis"] = (44.9778, -93.2650)
        cities["st. paul"] = (44.9537, -93.0900)
        cities["rochester mn"] = (44.0225, -92.4699) // Disambiguate from NY
        
        // Indiana
        cities["indianapolis"] = (39.7684, -86.1581)
        cities["fort wayne"] = (41.0793, -85.1394)
        cities["evansville"] = (37.9748, -87.5558)
        
        // Virginia
        cities["richmond"] = (37.5407, -77.4360)
        cities["norfolk"] = (36.8468, -76.2852)
        cities["virginia beach"] = (36.8529, -75.9780)
        
        // Connecticut
        cities["hartford"] = (41.7658, -72.6734)
        cities["new haven"] = (41.3083, -72.9279)
        cities["bridgeport"] = (41.1865, -73.1952)
        
        // Oregon
        cities["portland"] = (45.5152, -122.6784)
        cities["eugene"] = (44.0521, -123.0868)
        cities["salem"] = (44.9429, -123.0351)
        
        // Nevada
        cities["las vegas"] = (36.1699, -115.1398)
        cities["reno"] = (39.5296, -119.8138)
        cities["henderson"] = (36.0395, -114.9817)
        
        // Utah
        cities["salt lake city"] = (40.7608, -111.8910)
        cities["provo"] = (40.2338, -111.6585)
        cities["ogden"] = (41.2230, -111.9738)
        
        // Iowa
        cities["des moines"] = (41.5868, -93.6250)
        cities["cedar rapids"] = (41.9778, -91.6656)
        cities["davenport"] = (41.5236, -90.5776)
        
        // Kentucky
        cities["louisville"] = (38.2527, -85.7585)
        cities["lexington"] = (38.0406, -84.5037)
        cities["bowling green"] = (36.9685, -86.4808)
        
        // Alabama
        cities["birmingham"] = (33.5207, -86.8025)
        cities["montgomery"] = (32.3668, -86.3000)
        cities["huntsville"] = (34.7304, -86.5861)
        
        // South Carolina
        cities["charleston"] = (32.7765, -79.9311)
        cities["columbia"] = (33.9982, -81.0453)
        cities["greenville"] = (34.8526, -82.3940)
        
        // Oklahoma
        cities["oklahoma city"] = (35.4676, -97.5164)
        cities["tulsa"] = (36.1540, -95.9928)
        cities["norman"] = (35.2226, -97.4395)
        
        return cities
    }()
}

enum GeocodingError: LocalizedError {
    case noLocationFound
    
    var errorDescription: String? {
        switch self {
        case .noLocationFound:
            return "Could not find location for the provided address"
        }
    }
}

