//
//  RadioMacOSApp.swift
//  RadioMacOS
//
//  Created by Jonathan Fisher on 30/06/2022.
//

import SwiftUI

@main
struct RadioMacOSApp: App {
  
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  init() {
    AppDelegate.shared = self.appDelegate
    AppDelegate.shared.contentView = ContentView()
  }
  
  var body: some Scene {
    WindowGroup {
      AppDelegate.shared.contentView
    }
    Settings {
      SettingsView()
    }
  }
}

class StationModel: ObservableObject {
    @Published var station: Station? = nil
    @Published var isMuted = false
}

class NowPlayingStationModel: ObservableObject {
    static let shared = StationModel()

  @Published var station: Station? = nil
}

class AppDelegate: NSObject, NSApplicationDelegate {
  @AppStorage("feed_url") var feedUrl = "https://orllewin.uk/stations.json"
  @ObservedObject var nowPlaying = NowPlayingStationModel.shared
  static var shared : AppDelegate!
  var statusBarItem: NSStatusItem?
  var contentView: ContentView!
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusBarItem?.button?.title = "Radio"
  }
  
  func reload(){
    contentView.reload()
  }
  func setNowPlaying(station: Station){
    nowPlaying.station = station
  }
  
  func setStations(stations: [Station]){
    let menu = NSMenu()
    var index = 0
    for station in stations {
      print(station.title)
      index += 1
      let menuItem = NSMenuItem(title: station.title, action: #selector(play(_:)), keyEquivalent: "")
      menuItem.representedObject = station
      menu.addItem(menuItem)
    }
    
    menu.addItem(NSMenuItem.separator())
    menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    
    statusBarItem?.menu = menu
  }
  
  @objc func play(_ sender : NSMenuItem) {
    let station = sender.representedObject as! Station
    print("station to play: ")
    print(station.title)
    print(station.streamUrl)
    playStation(station: station)
  }
}
