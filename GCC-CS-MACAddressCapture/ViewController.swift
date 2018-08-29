//
//  ViewController.swift
//  GCC-CS-MACAddressCapture
//
//  Created by David Corbin on 8/28/18.
//  Copyright © 2018 David Corbin. All rights reserved.
//

import Cocoa

let slackWebhookURL = "https://hooks.slack.com/services/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"
let submitQuestionText = "Submit your MAC address to the GCC Computer Science department?"
let submitDescText = "Only supported on GCC Computer Science department MacBooks"

class ViewController: NSViewController {
    @IBOutlet weak var macAddressLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let intfIterator = findEthernetInterfaces() {
            if let macAddress = getMACAddress(intfIterator) {
                let macAddressAsString = macAddress.map({ String(format: "%02x", $0) })
                    .joined(separator: ":")
                macAddressLabel.stringValue = macAddressAsString

                DispatchQueue.main.async {
                    let status = self.alertPopup(question: submitQuestionText, text: submitDescText)
                    if status {
                        let url = URL(string: slackWebhookURL)!
                        var request = URLRequest(url: url)
                        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                        request.httpMethod = "POST"
                        let postString = "payload={\"text\":\"\(macAddressAsString)\"}"
                        request.httpBody = postString.data(using: .utf8)
                        let task = URLSession.shared.dataTask(with: request) { data, response, error in
                            guard let data = data, error == nil else {
                                DispatchQueue.main.async {
                                    _ = self.infoPopup(question: "Error receiving data", text: error.debugDescription)
                                }
                                return
                            }

                            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                                DispatchQueue.main.async {
                                    _ = self.infoPopup(question: "Error receiving data", text: error.debugDescription)
                                }
                            }

                            let responseString = String(data: data, encoding: .utf8)
                            print("responseString = \(String(describing: responseString))")

                            if responseString == "ok" {
                                DispatchQueue.main.async {
                                    _ = self.infoPopup(question: "Successfully received data", text: "Thank you")
                                }
                            }

                        }
                        task.resume()
                    }
                }
            }

            IOObjectRelease(intfIterator)
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func findEthernetInterfaces() -> io_iterator_t? {

        let matchingDict = IOServiceMatching("IOEthernetInterface") as NSMutableDictionary
        matchingDict["IOPropertyMatch"] = [ "IOPrimaryInterface": true]

        var matchingServices: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &matchingServices) != KERN_SUCCESS {
            return nil
        }

        return matchingServices
    }

    func getMACAddress(_ intfIterator: io_iterator_t) -> [UInt8]? {

        var macAddress: [UInt8]?

        var intfService = IOIteratorNext(intfIterator)
        while intfService != 0 {

            var controllerService: io_object_t = 0
            if IORegistryEntryGetParentEntry(intfService, "IOService", &controllerService) == KERN_SUCCESS {

                let dataUM = IORegistryEntryCreateCFProperty(controllerService,
                                                             "IOMACAddress" as CFString,
                                                             kCFAllocatorDefault,
                                                             0)
                if let data = dataUM?.takeRetainedValue() as? NSData {
                    macAddress = [0, 0, 0, 0, 0, 0]
                    data.getBytes(&macAddress!, length: macAddress!.count)
                }
                IOObjectRelease(controllerService)
            }

            IOObjectRelease(intfService)
            intfService = IOIteratorNext(intfIterator)
        }

        return macAddress
    }

    func alertPopup(question: String, text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }

    func infoPopup(question: String, text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        return alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn
    }

}
