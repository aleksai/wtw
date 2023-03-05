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
        case generating
        case waiting
        case game
        case gameover
    }
    
    static var shared = GameKit()
    
    private(set) var observables = GameKitObservable()
    
    private(set) var rounds = [[String:Any]]()
    private(set) var startDate: Date?
    
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
        observables.status = .matching

        let request = GKMatchRequest()
        request.minPlayers = 2

        let viewController = GKMatchmakerViewController(matchRequest: request)
        viewController?.matchmakerDelegate = self
        viewController?.matchmakingMode = .inviteOnly

        U.present(viewController)
    }
    
    public func shareplayMatch() async throws {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 10
        
        request.recipients = shareplayRecipients
        
        match = try await GKMatchmaker.shared().findMatch(for: request)
        match?.delegate = self
        
//        runGame()
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
        
        match?.chooseBestHostingPlayer { player in
            print("FIGHTER", GKLocalPlayer.local.gamePlayerID, player?.gamePlayerID)
            
            self.observables.status = GKLocalPlayer.local.gamePlayerID == player?.gamePlayerID ? .generating : .waiting
            
            if GKLocalPlayer.local.gamePlayerID == player?.gamePlayerID {
                Task {
                    await self.generateGame()
                    
                    let now = Date()
                    self.startDate = now.addingTimeInterval(5).addingTimeInterval(10 - now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10))
                    
                    if let data = try? JSONSerialization.data(withJSONObject: ["rounds": self.rounds, "startDate": Int(self.startDate!.timeIntervalSince1970)], options: []) {
                        try? self.match?.sendData(toAllPlayers: data, with: .reliable)
                    }
                    
                    self.observables.status = .game
                }
            }
        }
    }
    
    private func generateGame() async {
        let service = WeatherService()
        
        let randomLocations = GeoJSON.generateRandomLocations()
        
        var temperatures = [String]()
        
        rounds.removeAll()
        
        for location in randomLocations {
            do {
                let (hourly, _, _) = try await service.weather(for: location, including: .hourly, .daily, .alerts)
                
                if let string = hourly.forecast.last?.temperature.formatted() {
                    rounds.append(["latitude": Double(location.coordinate.latitude), "longitude": Double(location.coordinate.longitude), "answers": [string]])
                    temperatures.append(string)
                }
            } catch {
                print(error)
            }
        }
        
        for (i, _) in rounds.enumerated() {
            guard var answers = rounds[i]["answers"] as? [String] else { continue }
            while answers.count != 4 {
                if let wrong = temperatures.randomElement(), !answers.contains(where: { $0 == wrong }) {
                    answers.append(wrong)
                }
            }
            rounds[i]["answers"] = answers
        }
    }
    
}

extension GameKit: GKMatchmakerViewControllerDelegate {
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFindHostedPlayers players: [GKPlayer]) {
        print("AAAA")
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, hostedPlayerDidAccept player: GKPlayer) {
        print("MMMM")
    }
    
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
    
    func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
        print("PLAYER REQUEST", recipientPlayers)
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
        print("MATCH FROM TO", player, recipient, data)
        
        guard GKLocalPlayer.local.gamePlayerID == recipient.gamePlayerID, let data = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else { return }
        
        if let rounds = data["rounds"] as? [[String:Any]] {
            if let startDate = data["startDate"] as? Int {
                self.rounds = rounds
                self.startDate = Date(timeIntervalSince1970: TimeInterval(startDate))
                
                self.observables.status = .game
            }
        }
    }
    
}
