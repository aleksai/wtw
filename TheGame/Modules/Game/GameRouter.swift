//
//  GameRouter.swift
//  TheGame
//
//  Created by Aleksei Pugachev on 4.03.2023.
//

import Foundation

protocol GameRouterProtocol {
    
}

class GameRouter: BaseRouter {
    
    override func start(animated: Bool = false) {
        super.start(animated: animated)
        
        let viewController = GameView(nibName: "GameView", bundle: nil)
        
        viewController.router = self
        
        navigationController?.pushViewController(viewController, animated: animated)
    }
    
}

extension GameRouter: GameRouterProtocol {
    
    
    
}
