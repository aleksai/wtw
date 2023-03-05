//
//  GameView.swift
//  TheGame
//
//  Created by Aleksei Pugachev on 4.03.2023.
//

import UIKit
import Combine

class GameView: BaseView {

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var voiceButton: UIButton!
    @IBOutlet weak var gameoverView: UIView!
    
    @IBAction func playTap(_ sender: Any) {
        coordinator.findMatch()
    }
    
    @IBAction func stopTap(_ sender: Any) {
        coordinator.stopMatch()
    }
    
    @IBAction func voiceTap(_ sender: Any) {
        coordinator.toggleVoicechat()
    }
    
    struct Layout {
        static let something: CGFloat = 123
    }
    
    private let coordinator = GameCoordinator()
    public var router: GameRouterProtocol?
    
    private var disposeBag = Set<AnyCancellable>()
    
    override func setup() {
        playButton.isHidden = false
        stopButton.isHidden = true
        voiceButton.isHidden = true
        gameoverView.isHidden = true
    }
    
    override func bind() {
        coordinator.observables.$status.sink { status in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                switch status {
                case .invalid:
                    self.view.backgroundColor = .systemRed
                case .active:
                    self.view.backgroundColor = .systemTeal
                case .matching:
                    self.view.backgroundColor = .systemGreen
                case .game:
                    self.view.backgroundColor = .systemTeal
                case .gameover:
                    self.view.backgroundColor = .systemTeal
                }
                
                self.playButton.isHidden = status == .game
                self.stopButton.isHidden = status != .game
                self.voiceButton.isHidden = status != .game
                self.gameoverView.isHidden = status != .gameover
            }
        }
        .store(in: &disposeBag)
        
        coordinator.observables.$voicechat.sink { voicechat in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                self.voiceButton.setTitleColor(voicechat ? .black : .lightGray, for: .normal)
            }
        }
        .store(in: &disposeBag)
    }
    
}
