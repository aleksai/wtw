//
//  GeoJSON.swift
//  TheGame
//
//  Created by Aleksei Pugachev on 5.03.2023.
//

import CoreLocation

struct GeoJSONFeature {
    let type: String
    let geometry: GeoJSONGeometry
    let properties: [String: Any]?
}

enum GeoJSONGeometry {
    case point(coordinates: CLLocationCoordinate2D)
    // Add cases for other geometry types as needed
}

class GeoJSON {
    
    static func parse(_ jsonString: String) -> [GeoJSONFeature]? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                if let features = json["features"] as? [[String: Any]] {
                    return features.compactMap { featureJson in
                        if let geometryJson = featureJson["geometry"] as? [String: Any],
                           let type = featureJson["type"] as? String,
                           let geometryType = geometryJson["type"] as? String {
                            let geometry: GeoJSONGeometry?
                            switch geometryType {
                            case "Polygon":
                                if let coordinates = geometryJson["coordinates"] as? [[[Double]]], let coordinates = coordinates.first?.first {
                                    let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
                                    geometry = .point(coordinates: coordinate)
                                } else {
                                    geometry = nil
                                }
                            // Add cases for other geometry types as needed
                            default:
                                geometry = nil
                            }
                            let properties = featureJson["properties"] as? [String: Any]
                            return GeoJSONFeature(type: type, geometry: geometry ?? .point(coordinates: CLLocationCoordinate2D()), properties: properties)
                        } else {
                            return nil
                        }
                    }
                }
            }
        } catch {
            print("Error parsing GeoJSON: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    static func generateRandomLocations(_ amount: Int = 10) -> [CLLocation] {
        var randomLocations = [CLLocation]()
        
        if let path = Bundle.main.path(forResource: "land", ofType: "json"),
           let jsonString = try? String(contentsOfFile: path) {
            if let landFeatures = GeoJSON.parse(jsonString) {
                for _ in 1...amount {
                    if let feature = landFeatures.randomElement(), case .point(let coordinates) = feature.geometry {
                        randomLocations.append(CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude))
                    }
                }
            }
        }
        
        return randomLocations
    }
    
}
