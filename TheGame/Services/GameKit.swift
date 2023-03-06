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
    @Published var answers: [String:String] = [:]
    @Published var points: [String:Int] = [:]
    
}

class GameKit: NSObject {
    
    enum Status {
        case invalid
        case active
        case shareplay
        case matching
        case connecting
        case dice
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
    
    private var myDice = [Int]()
    private var dice = [String:[Int]]()
    private var generator = false
    
    private var avatars: [String:UIImage] = [:]
    
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
        request.maxPlayers = 10
        
        reset()

        let viewController = GKMatchmakerViewController(matchRequest: request)
        viewController?.matchmakerDelegate = self
        viewController?.matchmakingMode = .inviteOnly

        U.present(viewController)
    }
    
    public func shareplayMatch() async throws {
        let request = GKMatchRequest()
        
        request.minPlayers = 2
        request.maxPlayers = 10
        
        request.playerGroup = 101
        request.recipients = shareplayRecipients
        
        reset()
        
        let match = try await GKMatchmaker.shared().findMatch(for: request)
        setMatch(match)
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
    
    public func clearAnswers() {
        observables.answers.removeAll()
    }
    
    public func sendAnswer(_ answer: String, isRight: Bool) {
        if let data = try? JSONSerialization.data(withJSONObject: ["answer": answer, "isRight": isRight], options: []) {
            try? match?.sendData(toAllPlayers: data, with: .reliable)
        }
        
        if generator && isRight {
            addPoint(for: GKLocalPlayer.local.alias)
        }
    }
    
    public func getAvatarFor(_ id: String) -> UIImage? {
        avatars[id]
    }
    
}

extension GameKit {
    
    private func setMatch(_ match: GKMatch) {
        match.delegate = self
        
        self.match = match
        self.connect()
        
        self.match?.players.forEach { player in
            self.loadPlayerPhoto(player)
        }
    }
    
    private func loadPlayerPhoto(_ player: GKPlayer) {
        player.loadPhoto(for: .small) { photo, error in
            if let error {
                U.log(event: "GameKit.loadPhoto.error", error)
                return
            }
            
            if let photo {
                self.avatars[player.gamePlayerID] = photo
            }
        }
    }
    
    private func connect() {
        observables.status = .connecting
        
        tryToRunMatch()
    }
    
    private func checkDice() {
        print("DICE", myDice, dice, match?.players.count)
        
        guard dice.count == match?.players.count else { return }
        
        for i in 0...10 {
            var win = true
            var lose = false
            
            for oppDice in dice {
                if oppDice.value[i] >= myDice[i] {
                    win = false
                }
                
                if oppDice.value[i] > myDice[i] {
                    lose = true
                }
            }
            
            if lose {
                print("LOSE")
                
                observables.status = .waiting
                
                return
            }
            
            if win {
                print("WIN")
                observables.status = .generating
                                
                Task {
                    self.generator = true
                    
                    await self.generateGame()
                    
                    let now = Date()
                    self.startDate = now.addingTimeInterval(5).addingTimeInterval(10 - now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10))
                    
                    if let data = try? JSONSerialization.data(withJSONObject: ["rounds": self.rounds, "startDate": Int(self.startDate!.timeIntervalSince1970)], options: []) {
                        try? self.match?.sendData(toAllPlayers: data, with: .reliable)
                    }
                    
                    self.observables.status = .game
                }
                
                return
            }
        }
    }
    
    private func tryToRunMatch() {
        if match?.expectedPlayerCount == 0 {
            guard observables.status == .connecting else { return }
            
            observables.status = .dice
            
            let dice = (0...10).map { _ in Int.random(in: 1...1000) }
            myDice = dice
            
            checkDice()
            
            if let data = try? JSONSerialization.data(withJSONObject: ["dice": dice], options: []) {
                try? self.match?.sendData(toAllPlayers: data, with: .reliable)
            }
        }
    }
    
    private func generateGame() async {
        let service = WeatherService()
        
        let randomLocations = GeoJSON.generateRandomLocations(5)
        
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
    
    private func addPoint(for alias: String) {
        if observables.points[alias] == nil {
            observables.points[alias] = 1
        } else {
            observables.points[alias]! += 1
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: ["points": self.observables.points], options: []) {
            try? self.match?.sendData(toAllPlayers: data, with: .reliable)
        }
    }
    
    private func reset() {
        avatars.removeAll()
        dice.removeAll()
        
        generator = false
        
        observables.points.removeAll()
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

        setMatch(match)
    }
    
}

extension GameKit: GKLocalPlayerListener {
    
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        print("PLAYER ACCEPT")
        
        observables.status = .matching
        
        if invite.playerGroup == 101 {
            GKMatchmaker.shared().match(for: invite) { match, error in
                if let error {
                    U.log(event: "GameKit.invitematch.error", error)
                    return
                }
                
                if let match {
                    self.setMatch(match)
                }
            }
        } else {
            let viewController = GKMatchmakerViewController(invite: invite)
            viewController?.matchmakerDelegate = self

            U.present(viewController)
        }
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
        } else {
            loadPlayerPhoto(player)
            connect()
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
        
        if let dice = data["dice"] as? [Int] {
            print("MESSAGE DICE")
            self.dice[player.gamePlayerID] = dice
            
            checkDice()
        }
        
        if let rounds = data["rounds"] as? [[String:Any]] {
            if let startDate = data["startDate"] as? Int {
                print("MESSAGE ROUNDS")
                self.rounds = rounds
                self.startDate = Date(timeIntervalSince1970: TimeInterval(startDate))
                
                observables.status = .game
            }
        }
        
        if let answer = data["answer"] as? String {
            print("MESSAGE ANSWER")
            observables.answers[player.gamePlayerID] = answer
            
            if generator, let isRight = data["isRight"] as? Bool, isRight {
                addPoint(for: player.alias)
            }
        }
        
        if let points = data["points"] as? [String:Int] {
            print("MESSAGE POINTS")
            observables.points = points
        }
    }
    
}
