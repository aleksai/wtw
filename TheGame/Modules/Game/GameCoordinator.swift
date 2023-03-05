//
//  GameCoordinator.swift
//  TheGame
//
//  Created by Aleksei Pugachev on 4.03.2023.
//

import UIKit
import Combine
import CoreLocation

class GameCoordinatorObservable: ObservableObject {
    
    @Published fileprivate(set) var status = GameKit.Status.active
    @Published fileprivate(set) var voicechat = false
    
    @Published fileprivate(set) var round: [String:Any]?
    
    @Published fileprivate(set) var countdown: String?
    
    @Published fileprivate(set) var answered = (0,0)
    @Published fileprivate(set) var answer: String?
    
}

class GameCoordinator {
    
    private(set) var observables = GameCoordinatorObservable()

    private var disposeBag = Set<AnyCancellable>()
    
    private var round = 0
    
    private var gameTimer: Timer?
    
    init() {
        GameKit.shared.observables.$status.sink { status in
            self.observables.status = status
            
            if status == .game {
                self.startGame()
            }
        }
        .store(in: &disposeBag)
        
        GameKit.shared.observables.$voicechat.sink { voicechat in
            self.observables.voicechat = voicechat
        }
        .store(in: &disposeBag)
    }
    
}

extension GameCoordinator {
    
    private func startGame() {
        observables.round = nil
        observables.answer = nil
        observables.answered = (0,0)
        observables.voicechat = false
        
        observables.countdown = "READY"
        
        round = 0
            
        if let startDate = GameKit.shared.startDate {
            gameTimer = Timer(fireAt: startDate, interval: 5, target: self, selector: #selector(goNextRound), userInfo: nil, repeats: true)
            RunLoop.main.add(gameTimer!, forMode: .default)
            
            let countdownTimer = Timer(fire: Calendar.current.date(byAdding: .second, value: -3, to: startDate)!, interval: 1, repeats: true, block: { timer in
                if self.observables.countdown == "READY" {
                    self.observables.countdown = "3"
                } else if self.observables.countdown == "3" {
                    self.observables.countdown = "2"
                } else if self.observables.countdown == "2" {
                    self.observables.countdown = "1"
                } else {
                    self.observables.countdown = nil
                    timer.invalidate()
                }
            })
            RunLoop.main.add(countdownTimer, forMode: .default)
        }
    }
    
    @objc private func goNextRound() {
        print("NEXT ROUND")
        
        guard observables.status == .game && GameKit.shared.rounds.count > round else {
            gameTimer?.invalidate()
            
            if observables.status == .game {
                GameKit.shared.stopMatch()
            }
            return
        }
        
        observables.answer = nil
        observables.round = GameKit.shared.rounds[round]
        round += 1
    }
    
}

extension GameCoordinator {
    
    public func findMatch() {
        GameKit.shared.findMatch()
    }
    
    public func shareplayMatch() {
        Task {
            try? await GameKit.shared.shareplayMatch()
        }
    }
    
    public func stopMatch() {
        GameKit.shared.stopMatch()
    }
    
    public func toggleVoicechat() {
        GameKit.shared.toggleVoicechat()
    }
    
    public func answer(_ answer: String) {
        observables.answer = answer
        observables.answered.0 += 1
        
        if answer == (observables.round?["answers"] as? [String])?.first {
            observables.answered.1 += 1
        }
    }
    
}
