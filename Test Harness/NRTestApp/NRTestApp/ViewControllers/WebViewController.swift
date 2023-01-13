//
//  WebViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/13/23.
//

import UIKit
#if os(iOS)
import WebKit

class WebViewController: UIViewController, WKUIDelegate {
    let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Web View"
        self.view.backgroundColor = .white

    }
    
    override func loadView() {
        super.loadView()
        webView.uiDelegate = self

        if let url = URL(string: "https://www.newrelic.com") {
            webView.load(URLRequest(url: url))
            view = webView
        }
    }
}

#endif
