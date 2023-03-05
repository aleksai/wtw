//
//  GameView.swift
//  TheGame
//
//  Created by Aleksei Pugachev on 4.03.2023.
//

import UIKit
import Combine
import MapKit

class GameView: BaseView {

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var shareplayButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var voiceButton: UIButton!
    @IBOutlet weak var gameoverView: UIView!
    @IBOutlet weak var prepareView: UIView!
    @IBOutlet weak var mapView: UIView!
    @IBOutlet weak var gameView: UIView!
    
    @IBOutlet var answerButtons: [UIButton]!
    
    @IBAction func playTap(_ sender: Any) {
        coordinator.findMatch()
    }
    
    @IBAction func shareplayTap(_ sender: Any) {
        coordinator.shareplayMatch()
    }
    
    @IBAction func stopTap(_ sender: Any) {
        coordinator.stopMatch()
    }
    
    @IBAction func voiceTap(_ sender: Any) {
        coordinator.toggleVoicechat()
    }
    
    @IBAction func answerTap(_ sender: Any) {
        guard let answer = (sender as? UIButton)?.title(for: .normal) else { return }
        coordinator.answer(answer)
    }
    
    struct Layout {
        
    }
    
    private let coordinator = GameCoordinator()
    public var router: GameRouterProtocol?
    
    private var disposeBag = Set<AnyCancellable>()
    
    override func setup() {
        playButton.isHidden = false
        shareplayButton.isHidden = true
        stopButton.isHidden = true
        voiceButton.isHidden = true
        gameoverView.isHidden = true
        prepareView.isHidden = true
        mapView.isHidden = true
        gameView.isHidden = true
    }
    
    override func appear() {
        mapView.layer.cornerRadius = mapView.frame.height / 2
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
                case .matching, .shareplay:
                    self.view.backgroundColor = .systemGreen
                case .prepare, .generating, .waiting, .game:
                    self.view.backgroundColor = .white
                    
                    switch status {
                    case .prepare:
                        (self.prepareView.subviews.first as? UILabel)?.text = "ROLLING A DICE..."
                    case .waiting:
                        (self.prepareView.subviews.first as? UILabel)?.text = "WAITING..."
                    case .generating:
                        (self.prepareView.subviews.first as? UILabel)?.text = "GENERATING..."
                    default: break
                    }
                case .gameover:
                    self.view.backgroundColor = .systemTeal
                }
                
                self.playButton.isHidden = status != .active && status != .gameover
                self.shareplayButton.isHidden = status != .shareplay
                self.stopButton.isHidden = status != .game
                self.voiceButton.isHidden = status != .game
                self.mapView.isHidden = status != .game || self.coordinator.observables.countdown != nil
                self.gameoverView.isHidden = status != .gameover
                self.prepareView.isHidden = status != .prepare && status != .generating && status != .waiting && self.coordinator.observables.countdown == nil
                self.gameView.isHidden = status != .game || self.coordinator.observables.countdown != nil
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
        
        coordinator.observables.$countdown.sink { countdown in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                if let countdown {
                    (self.prepareView.subviews.first as? UILabel)?.text = "\(countdown)"
                } else {
                    if self.coordinator.observables.status == .game {
                        self.gameView.isHidden = false
                        self.mapView.isHidden = false
                        self.prepareView.isHidden = true
                    }
                }
            }
        }
        .store(in: &disposeBag)
        
        coordinator.observables.$round.sink { round in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                guard let map = self.mapView.subviews.first as? MKMapView, let latitide = round?["latitude"] as? Double, let longitude = round?["longitude"] as? Double else { return }
                
                let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: latitide, longitude: longitude), span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10))
                map.setRegion(region, animated: true)
                
                let geocoder = CLGeocoder()
                 
                geocoder.reverseGeocodeLocation(CLLocation(latitude: latitide, longitude: longitude), preferredLocale: Locale.init(identifier: "en_US")) { (placemarks, error) in
                    guard let placemark = placemarks?.first else { return }
                    
                    (self.gameView.subviews.first as? UILabel)?.text = "What's the temperature\(placemark.country == nil ? "?" : " in \(placemark.country ?? "")?")"
                }
                
                guard let answers = (round?["answers"] as? [String])?.shuffled() else { return }
                
                for (i, button) in self.answerButtons.enumerated() {
                    button.setTitle(answers[i], for: .normal)
                }
            }
        }
        .store(in: &disposeBag)
        
        coordinator.observables.$answered.sink { answered in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                (self.gameoverView.subviews.first as? UILabel)?.text = "\(answered.1)/\(answered.0)"
            }
        }
        .store(in: &disposeBag)
        
        coordinator.observables.$answer.sink { answer in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                for button in self.answerButtons {
                    button.isUserInteractionEnabled = answer == nil
                    button.backgroundColor = answer == button.title(for: .normal) ? .green : .black
                }
            }
        }
        .store(in: &disposeBag)
    }
    
}
