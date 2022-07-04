//
//  ContentView.swift
//  RadioMacOS
//
//  Created by Jonathan Fisher on 30/06/2022.
//
import Cocoa
import SwiftUI
import Combine
import AVKit

let cellWidth = 250.0
let buttonSize = 32.0
private var radioStatusItem: NSStatusItem!
private var player: AVPlayer!



struct Stations: Decodable, Hashable  {
  var stations: [Station]
}
struct Station: Decodable, Hashable  {
  let title: String
  let website: URL
  let streamUrl: URL
  let logoUrl: URL
  let colour: String
}

struct SettingsView: View{
  @State private var stationsUrl = ""
  @Environment(\.presentationMode) var presentationMode
  var body: some View {
    VStack {
      Text("Override stations JSON feed:")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      TextField("Stations JSON feed Url", text: AppDelegate.shared.$feedUrl)
      Button(action: {
        AppDelegate.shared.reload()
        presentationMode.wrappedValue.dismiss()
      }) {
        Text("Update")
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }
    .frame(width: 400, height: 55, alignment: .leading)
    .padding()
  }
}

struct ContentView: View {
  @ObservedObject var nowPlaying = NowPlayingStationModel.shared
  @ObservedObject var stationsRemoveObservable = StationsRemoteObservable()
  private var threeColumnGrid = [GridItem(.fixed(100)), GridItem(.fixed(100)), GridItem(.fixed(100))]
  private var oneColumnGrid = [GridItem(.fixed(cellWidth))]
  @State private var hover: Bool = false
  var index = 0
  func reload(){
    stationsRemoveObservable.loadFeed()
  }
  
  var body: some View {
    ScrollView {
      VStack{
        if(nowPlaying.station != nil){
          HStack{
            AsyncImage(
              url: nowPlaying.station?.logoUrl,
              content: { image in
                image.resizable()
                  .aspectRatio(contentMode: .fit)
              },
              placeholder: {
                ProgressView()
              }
            ).id("top")
            .frame(width: buttonSize, height: buttonSize)
            .clipShape(Circle())
            .padding([.leading], 20)
            Image(systemName: "stop.circle.fill")
              .resizable()
              .frame(width: buttonSize, height: buttonSize)
              .onTapGesture {
                player.replaceCurrentItem(with: nil)
                AppDelegate.shared.nowPlaying.station = nil
              }
              .onHover{ isHovered in
                self.hover = isHovered
                if (hover) {
                  NSCursor.pointingHand.push()
                } else {
                  NSCursor.pop()
                }
              }
            if(nowPlaying.isMuted){
              Image(systemName: "speaker.circle.fill")
                .resizable()
                .frame(width: buttonSize, height: buttonSize)
                .onTapGesture {
                  player.isMuted = false
                  nowPlaying.isMuted = false
                }
                .onHover{ isHovered in
                  self.hover = isHovered
                  if (hover) {
                    NSCursor.pointingHand.push()
                  } else {
                    NSCursor.pop()
                  }
                }
            }else{
              Image(systemName: "speaker.slash.circle.fill")
                .resizable()
                .frame(width: buttonSize, height: buttonSize)
                .onTapGesture {
                  player.isMuted = true
                  nowPlaying.isMuted = true
                }
                .onHover{ isHovered in
                  self.hover = isHovered
                  if (hover) {
                    NSCursor.pointingHand.push()
                  } else {
                    NSCursor.pop()
                  }
                }
            }
            Link(destination: nowPlaying.station!.website, label: {
              Image(systemName: "link.circle.fill")
                .resizable()
                .foregroundColor(Color.black)
                .frame(width: buttonSize, height: buttonSize)
            })
            Spacer().frame(maxWidth: .infinity, alignment: .leading)
          }.padding([.top], 26)
          
          Text(nowPlaying.station?.title ?? "").padding([.leading], 20).padding([.top], 10).frame(maxWidth: .infinity, alignment: .leading)
        }
        
        
        LazyVGrid(columns: oneColumnGrid) {
          
          ForEach(stationsRemoveObservable.stations.stations, id: \.self){ station in
            
            HStack {
              AsyncImage(
                url: station.logoUrl,
                content: { image in
                  image.resizable()
                    .aspectRatio(contentMode: .fit)
                },
                placeholder: {
                  ProgressView()
                }
              )
              .frame(width: 45, height: 45)
              .clipShape(Circle())
              .padding([.leading], 10)
              Text(station.title)
                .font(.title2)
              Link(destination: station.website, label: {
                Image(systemName: "link.circle.fill")
                  .resizable()
                  .foregroundColor(Color.black)
                  .frame(width: 26, height: 26)
              })
              .frame(maxWidth: .infinity, alignment: .trailing).padding(10)
            }
            .frame(width: cellWidth, height: 75, alignment: Alignment.leading)
            
            .background(SwiftUI.Color(NSColor(hex: station.colour)))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .cornerRadius(15)
            .onTapGesture {
              playStation(station: station)
            }
            .onHover{ isHovered in
              self.hover = isHovered
              if (hover) {
                NSCursor.pointingHand.push()
              } else {
                NSCursor.pop()
              }
            }
          }
        }
        .padding()
      }
    }
    
  }
}

func playStation(station: Station){
  print(station.title)
  setStatusBarTitle(title: station.title)
  let playerItem = AVPlayerItem.init(url: station.streamUrl)
  player = AVPlayer.init(playerItem: playerItem)
  player.play()
  AppDelegate.shared.setNowPlaying(station: station)
}

func setStatusBarTitle(title: String){
  AppDelegate.shared.statusBarItem?.button?.title = title
}


class StationsRemoteObservable: ObservableObject{
  
  private var can: AnyCancellable?
  @Published var stations = Stations(stations: [])
  
  init(){
    loadFeed()
  }
  
  func loadFeed() {
    let url = AppDelegate.shared.feedUrl
    print("Using feed url: " + url)
    let urlRequest = URLRequest(url: URL(string: url)!)
    
    let dataTask = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
      if let error = error {
        print("Request error: ", error)
        return
      }
      
      guard let response = response as? HTTPURLResponse else { return }
      
      if response.statusCode == 200 {
        guard let data = data else {
          return
        }
        DispatchQueue.main.async {
          
          let decoder = JSONDecoder()
          
          let stations = try! decoder.decode(Stations.self, from: data)
          
          for station in stations.stations {
            print(station.title)
          }
          
          self.stations.stations = stations.stations
          AppDelegate.shared.setStations(stations: stations.stations)
        }
      }
    }
    dataTask.resume()
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}

extension NSColor {
  
  convenience init(hex: String) {
    let trimHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    let dropHash = String(trimHex.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    let hexString = trimHex.starts(with: "#") ? dropHash : trimHex
    let ui64 = UInt64(hexString, radix: 16)
    let value = ui64 != nil ? Int(ui64!) : 0
    // #RRGGBB
    var components = (
      R: CGFloat((value >> 16) & 0xff) / 255,
      G: CGFloat((value >> 08) & 0xff) / 255,
      B: CGFloat((value >> 00) & 0xff) / 255,
      a: CGFloat(1)
    )
    if String(hexString).count == 8 {
      // #RRGGBBAA
      components = (
        R: CGFloat((value >> 24) & 0xff) / 255,
        G: CGFloat((value >> 16) & 0xff) / 255,
        B: CGFloat((value >> 08) & 0xff) / 255,
        a: CGFloat((value >> 00) & 0xff) / 255
      )
    }
    self.init(red: components.R, green: components.G, blue: components.B, alpha: components.a)
  }
}
