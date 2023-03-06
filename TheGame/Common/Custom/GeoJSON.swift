//
//  GeoJSON.swift
//  TheGame
//
//  Created by Aleksei Pugachev on 5.03.2023.
//

import CoreLocation

struct GeoCity {
    let name: String
    let lat: String
    let lng: String
}

class GeoJSON {
    
    static func generateRandomLocations(_ amount: Int = 5) -> [CLLocation] {
        var randomLocations = [CLLocation]()
        
        if let path = Bundle.main.path(forResource: "cities", ofType: "json"), let jsonString = try? String(contentsOfFile: path) {
            guard let jsonData = jsonString.data(using: .utf8) else { return [] }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String:String]] {
                    let randomCities = json[randomPick: amount].compactMap { cityJson in
                        if let name = cityJson["name"], let lat = cityJson["lat"], let lng = cityJson["lng"] {
                            return GeoCity(name: name, lat: lat, lng: lng)
                        } else {
                            return nil
                        }
                    }
                    
                    for city in randomCities {
                        randomLocations.append(CLLocation(latitude: Double(city.lat) ?? 0, longitude: Double(city.lng) ?? 0))
                    }
                }
            } catch {
                print("Error parsing GeoJSON: \(error.localizedDescription)")
            }
        }
        
        return randomLocations
    }
    
}
