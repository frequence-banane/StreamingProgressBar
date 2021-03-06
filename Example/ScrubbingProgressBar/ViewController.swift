//
//  ViewController.swift
//  ScrubbingProgressBar
//
//  Created by Kyle Zaragoza on 08/23/2016.
//  Copyright (c) 2016 Kyle Zaragoza. All rights reserved.
//

import UIKit
import ScrubbingProgressBar

class ViewController: UIViewController {

    @IBOutlet weak var progressBar: ScrubbingProgressBar!
    @IBOutlet weak var resetButton: UIButton!
    var playTimer: Timer?
    var bufferTimer: Timer?
    
    @IBAction func resetClicked(_ sender: UIButton) {
        progressBar.progress = 0.5
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        return
        /*
        playTimer = Timer.scheduledTimer(
            timeInterval: 1/30,
            target: self,
            selector: #selector(incrementPlayTimer),
            userInfo: nil,
            repeats: true)*/
        bufferTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(incrementBufferProgress),
            userInfo: nil,
            repeats: true)
    }
    
    func incrementPlayTimer() {
        let updatedProgress = progressBar.progress + 0.002
        if updatedProgress > 1 {
            progressBar.progress = 0
            progressBar.secondaryProgress = 0
        } else {
            progressBar.progress = updatedProgress
        }
    }
    
    @objc func incrementBufferProgress() {
        progressBar.secondaryProgress += 0.1
    }
}

