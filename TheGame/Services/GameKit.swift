//
//  GameKit.swift
//  TheGame
//
//  Created by Aleksei Pugachev on 4.03.2023.
//

import GameKit
import WeatherKit
import MapKit
import CoreLocation
import Combine

class GameKitObservable: ObservableObject {
    
    @Published var status = GameKit.Status.active
    @Published var voicechat = false
    
}

class GameKit: NSObject {
    
    enum Status {
        case invalid
        case active
        case shareplay
        case matching
        case prepare
        case game
        case gameover
    }
    
    static var shared = GameKit()
    
    private(set) var observables = GameKitObservable()
    
    private(set) var rounds = [(CLLocation,[String])]()
    
    private var shareplayRecipients = [GKPlayer]() {
        didSet {
            if !shareplayRecipients.isEmpty {
                observables.status = .shareplay
            }
        }
    }
    
    private var match: GKMatch?
    private var voiceChat: GKVoiceChat?
    
    public func start() {
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            if let viewController = viewController {
                print("GC VC", viewController)
                return
            }
            
            guard error == nil else {
                print("GC ERROR", error)
                return
            }
            
            self.observables.status = .active
            
            if GKLocalPlayer.local.isUnderage {
                print("GC UNDERAGE")
            }
            
            if GKLocalPlayer.local.isMultiplayerGamingRestricted {
                print("GC MULTIPLAYER RESTRICTED")
            }
            
            if GKLocalPlayer.local.isPersonalizedCommunicationRestricted {
                print("GC VOICE CHAT DISABLED")
            }
            
            print("GC", GKLocalPlayer.local.isAuthenticated, GKLocalPlayer.local.isPresentingFriendRequestViewController, GKLocalPlayer.local.isInvitable)
            
            GKLocalPlayer.local.register(self)
            
            GKAccessPoint.shared.location = .topLeading
            GKAccessPoint.shared.showHighlights = true
            GKAccessPoint.shared.isActive = true
            
            GKMatchmaker.shared().startGroupActivity { player in
                print("GA PLAYER", player)
                
                guard !self.shareplayRecipients.contains(where: { $0.gamePlayerID == player.gamePlayerID }) else { return }
                
                self.shareplayRecipients.append(player)
            }
        }
    }
    
    public func findMatch() {
        runGame()
        
//        observables.status = .matching
//
//        let request = GKMatchRequest()
//        request.minPlayers = 2
//
//        let viewController = GKMatchmakerViewController(matchRequest: request)
//        viewController?.matchmakerDelegate = self
//        viewController?.matchmakingMode = .inviteOnly
//
//        U.present(viewController)
    }
    
    public func shareplayMatch() async throws {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.recipients = shareplayRecipients
        
        match = try await GKMatchmaker.shared().findMatch(for: request)
        match?.delegate = self
        
        runGame()
    }
    
    public func stopMatch() {
        print("STOP MATCH")
        
        match?.disconnect()
        
        match = nil
        voiceChat = nil
        
        observables.status = .gameover
        observables.voicechat = false
    }
    
    public func toggleVoicechat() {
        print("VOICE CHAT")
        
        if voiceChat == nil {
            voiceChat = match?.voiceChat(withName: "aleksai.game.voice.chat")
            
            voiceChat?.start()
            voiceChat?.isActive = true
            
            observables.voicechat = true
        } else {
            voiceChat?.isActive = false
            voiceChat?.stop()
            
            voiceChat = nil
            
            observables.voicechat = false
        }
    }
    
}

extension GameKit {
    
    private func runGame() {
        observables.status = .prepare
        
        Task {
            await generateGame()
        }
    }
    
    private func generateGame() async {
        let service = WeatherService()
        
        let randomLocations = generateRandomLocations()
        
        var temperatures = [String]()
        
        rounds.removeAll()
        
        print("TEST2", randomLocations.count)
        
        for location in randomLocations {
            do {
                let (hourly, _, _) = try await service.weather(for: location, including: .hourly, .daily, .alerts)
                
                if let string = hourly.forecast.last?.temperature.formatted() {
                    rounds.append((location,[string]))
                    temperatures.append(string)
                }
            } catch {
                print(error)
            }
        }
        
        print("TEST3", rounds.count)
        
        for (i, _) in rounds.enumerated() {
            while rounds[i].1.count != 4 {
                if let wrong = temperatures.randomElement(), !rounds[i].1.contains(where: { $0 == wrong }) {
                    rounds[i].1.append(wrong)
                }
            }
        }
        
        observables.status = .game
    }
    
    private func generateRandomLocations() -> [CLLocation] {
        var randomLocations = [CLLocation]()
        
        if let path = Bundle.main.path(forResource: "land", ofType: "json"),
           let jsonString = try? String(contentsOfFile: path) {
            if let landFeatures = GeoJSON.parse(jsonString) {
                for _ in 1...10 {
                    if let feature = landFeatures.randomElement(), case .point(let coordinates) = feature.geometry {
                        randomLocations.append(CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude))
                    }
                }
            }
        }
        
        print("TEST1", randomLocations.count)
        
        return randomLocations
    }
    
}

extension GameKit: GKMatchmakerViewControllerDelegate {
    
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        print("MATCH VC CANCEL", viewController)
        
        viewController.dismiss(animated: true)
        
        observables.status = .active
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        print("MATCH VC", viewController, error)
        
        observables.status = .invalid
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        print("MATCH FIND")
        
        viewController.dismiss(animated: true, completion: nil)

        match.delegate = self
        
        self.match = match
        self.runGame()
    }
    
}

extension GameKit: GKLocalPlayerListener {
    
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        print("PLAYER ACCEPT")
        
        observables.status = .matching
        
        let viewController = GKMatchmakerViewController(invite: invite)
        viewController?.matchmakerDelegate = self
        
        U.present(viewController)
    }
    
}

extension GameKit: GKMatchDelegate {
    
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        print("MATCH PLAYER STATE", player, state)
        
        if state == .disconnected {
            stopMatch()
        }
    }
    
    func match(_ match: GKMatch, didFailWithError error: Error?) {
        print("MATCH FAIL", error)
    }
    
    func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
        print("MATCH SHOULD REINVITE")
        return false
    }
    
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        print("MATCH FROM", player, data)
    }
    
    func match(_ match: GKMatch, didReceive data: Data, forRecipient recipient: GKPlayer, fromRemotePlayer player: GKPlayer) {
        print("MATCH FROM TO", player, recipient)
    }
    
}
