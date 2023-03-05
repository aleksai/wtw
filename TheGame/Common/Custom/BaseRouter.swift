//
//  BaseRouter.swift
//  TheGame
//
//  Created by Alek Sai on 18.09.2022.
//

import UIKit

protocol BaseRouterProtocol {
    func start(animated: Bool)
}

class BaseRouter {
    
    weak var navigationController: UINavigationController?
    
    init(navigationController: UINavigationController?) {
        self.navigationController = navigationController
    }

}

extension BaseRouter: BaseRouterProtocol {
    
    @objc func start(animated: Bool = false) {
        U.log(event: "baserouter.next", String(NSStringFromClass(type(of: self))))
    }
    
}
