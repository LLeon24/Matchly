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
    static func geocodeAddress(_ addressString: String) async throws -> CLLocation {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = addressString
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        guard let mapItem = response.mapItems.first else {
            throw GeocodingError.noLocationFound
        }
        
        // In iOS 26.0+, location is non-optional
        let location = mapItem.location
        return location
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
        // First try to find the city in major cities lookup
        let cityKey = city.lowercased().trimmingCharacters(in: .whitespaces)
        let cities = majorCities
        
        if let cityCoords = cities[cityKey] {
            return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
        }
        
        // Try with state disambiguation for cities with same name
        let stateAbbrev = state.uppercased()
        if cityKey == "springfield" {
            if stateAbbrev == "MA", let cityCoords = cities["springfield ma"] {
                return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
            }
            if stateAbbrev == "MO", let cityCoords = cities["springfield mo"] {
                return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
            }
        }
        
        if cityKey == "rochester" {
            if stateAbbrev == "NY", let cityCoords = cities["rochester"] {
                return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
            }
            if stateAbbrev == "MN", let cityCoords = cities["rochester mn"] {
                return CLLocationCoordinate2D(latitude: cityCoords.lat, longitude: cityCoords.lon)
            }
        }
        
        // Fallback to state center
        return coordinate(for: state)
    }
    
    /// Geographic center of each US state. Built once and cached.
    private static let stateCenters: [String: (lat: Double, lon: Double)] = [
        "AL": (32.806671, -86.791130), "AK": (61.370716, -152.404419), "AZ": (33.729759, -111.431221),
        "AR": (34.969704, -92.373123), "CA": (36.116203, -119.681564), "CO": (39.059811, -105.311104),
        "CT": (41.597782, -72.755371), "DE": (39.318523, -75.507141), "FL": (27.766279, -81.686783),
        "GA": (33.040619, -83.643074), "HI": (21.094318, -157.498337), "ID": (44.240459, -114.478828),
        "IL": (40.349457, -88.986137), "IN": (39.849426, -86.258278), "IA": (42.011539, -93.210526),
        "KS": (38.526600, -96.726486), "KY": (37.668140, -84.670067), "LA": (31.169546, -91.867805),
        "ME": (44.323535, -69.765261), "MD": (39.063946, -76.802101), "MA": (42.2352, -71.0275),
        "MI": (43.326618, -84.536095), "MN": (45.694454, -93.900192), "MS": (32.320, -89.207),
        "MO": (38.456085, -92.288368), "MT": (46.921925, -110.454353), "NE": (41.125370, -98.268082),
        "NV": (38.313515, -117.055374), "NH": (43.452492, -71.563896), "NJ": (40.298904, -74.521011),
        "NM": (34.840515, -106.248482), "NY": (42.165726, -74.948051), "NC": (35.630066, -79.806419),
        "ND": (47.528912, -99.784012), "OH": (40.388783, -82.764915), "OK": (35.565342, -96.928917),
        "OR": (44.572021, -122.070938), "PA": (40.590752, -77.209755), "RI": (41.680893, -71.51178),
        "SC": (33.856892, -80.945007), "SD": (44.299782, -99.438828), "TN": (35.747845, -86.692345),
        "TX": (31.054487, -97.563461), "UT": (40.150032, -111.862434), "VT": (44.045876, -72.710686),
        "VA": (37.769337, -78.169968), "WA": (47.400902, -121.490494), "WV": (38.491226, -80.954453),
        "WI": (44.268543, -89.616508), "WY": (42.755966, -107.302490), "DC": (38.907192, -77.036873)
    ]
    
    /// Get coordinate for state only
    static func coordinate(for state: String) -> CLLocationCoordinate2D {
        let stateAbbrev = state.uppercased()
        if let coords = stateCenters[stateAbbrev] {
            return CLLocationCoordinate2D(latitude: coords.lat, longitude: coords.lon)
        }
        
        // Default to center of USA
        return CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795)
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

