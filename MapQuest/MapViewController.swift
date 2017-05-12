/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import MapKit

class MapViewController: UIViewController {

  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var heartsLabel: UILabel!

  var tileRenderer: MKTileOverlayRenderer!
  var shimmerRenderer: ShimmerRenderer!

  override func viewDidLoad() {
    super.viewDidLoad()

    setupTileRenderer()
    setupLakeOverlay()

    let initialRegion = MKCoordinateRegion(center:  CLLocationCoordinate2D(latitude: 40.774669555422349, longitude:  -73.964170794293238),
                                           span: MKCoordinateSpan(latitudeDelta: 0.16405544070813249, longitudeDelta: 0.1232528799585566))
    mapView.region = initialRegion
    mapView.showsUserLocation = true
    mapView.showsCompass = true
    mapView.setUserTrackingMode(.followWithHeading, animated: true)

    Game.shared.delegate = self

    NotificationCenter.default.addObserver(self, selector: #selector(gameUpdated(notification:)), name: GameStateNotification, object: nil)

    mapView.delegate = self
    mapView.addAnnotations(Game.shared.warps)
  }

  func setupTileRenderer() {
    let overlay = AdventureMapOverlay()
    
    overlay.canReplaceMapContent = true
    mapView.add(overlay, level: MKOverlayLevel.aboveLabels)
    tileRenderer = MKTileOverlayRenderer(tileOverlay: overlay)
    
    overlay.minimumZ = 13
    overlay.maximumZ = 16
  }

  func setupLakeOverlay() {
    
    // 1
    let lake = MKPolygon(coordinates: &Game.shared.reservoir, count: Game.shared.reservoir.count)
    mapView.add(lake)
    
    // 2
    shimmerRenderer = ShimmerRenderer(overlay: lake)
    shimmerRenderer.fillColor = #colorLiteral(red: 0.2431372549, green: 0.5803921569, blue: 0.9764705882, alpha: 1)
    
    // 3
    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.shimmerRenderer.updateLocations()
      self?.shimmerRenderer.setNeedsDisplay()
    }
  }

  func gameUpdated(notification: Notification) {
    renderGame()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    renderGame()
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "shop", let shopController = segue.destination as? ShopViewController, let store = sender as? Store {
      shopController.shop = store
    }
  }

}

// MARK: - MapView Delegate
extension MapViewController: MKMapViewDelegate {
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if overlay is AdventureMapOverlay {
      return tileRenderer
    } else {
      return shimmerRenderer
    }
  }
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    switch annotation {
      
    // 1
    case let user as MKUserLocation:
      
      // 2
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: "user")
        ?? MKAnnotationView(annotation: user, reuseIdentifier: "user")
      
      // 3
      view.image = #imageLiteral(resourceName: "user")
      return view
      
    case let warp as WarpZone:
      let view = mapView.dequeueReusableAnnotationView(withIdentifier: WarpAnnotationView.identifier)
        ?? WarpAnnotationView(annotation: warp, reuseIdentifier: WarpAnnotationView.identifier)
      view.annotation = warp
      return view
      
    default:
      return nil
    }
  }
}

// MARK: - Game UI
extension MapViewController {
  private func heartsString() -> String {
    guard let hp = Game.shared.adventurer?.hitPoints else { return "☠️" }
    let heartCount = hp / 2
    var string = ""
    for _ in 1 ... heartCount {
      string += "❤️"
    }
    return string
  }
  private func goldString() -> String {
    guard let gold = Game.shared.adventurer?.gold else { return "" }
    return "💰\(gold)"
  }
  fileprivate func renderGame() {
    heartsLabel.text = heartsString() + "\n" + goldString()
  }
}

// MARK: - Game Delegate
extension MapViewController: GameDelegate {
  func encounteredMonster(monster: Monster) {
    showFight(monster: monster)
  }

  func showFight(monster: Monster, subtitle: String = "Fight?") {
    let alert = AABlurAlertController()

    alert.addAction(action: AABlurAlertAction(title: "Run", style: AABlurActionStyle.cancel) { [unowned self] _ in
      self.showFight(monster: monster, subtitle: "I think you should really fight this.")
    })
    alert.addAction(action: AABlurAlertAction(title: "Fight", style: AABlurActionStyle.default) { [unowned self] _ in
      guard let result = Game.shared.fight(monster: monster) else { return }
      switch result {
      case .HeroLost:
        print("loss!")
      case .HeroWon:
        print("win!")
      case .Tie:
        self.showFight(monster: monster, subtitle: "A good row, but you are both still in the fight!")
      }
    })
    alert.blurEffectStyle = .regular
    let image = Game.shared.image(for: monster)
    alert.alertImage.image = image
    alert.alertTitle.text = "A wild \(monster.name) appeared!"
    alert.alertSubtitle.text = subtitle
    present(alert, animated: true) {}
  }

  func encounteredNPC(npc: NPC) {
    let alert = AABlurAlertController()

    alert.addAction(action: AABlurAlertAction(title: "No Thanks", style: AABlurActionStyle.cancel) {  _ in
      print("done with encounter")
    })
    alert.addAction(action: AABlurAlertAction(title: "On My Way", style: AABlurActionStyle.default) {  _ in
      print("did not buy anything")
    })
    alert.blurEffectStyle = .regular
    let image = Game.shared.image(for: npc)
    alert.alertImage.image = image
    alert.alertTitle.text = npc.name
    alert.alertSubtitle.text = npc.quest
    present(alert, animated: true) {}

  }

  func enteredStore(store: Store) {
    let alert = AABlurAlertController()

    alert.addAction(action: AABlurAlertAction(title: "Back Out", style: AABlurActionStyle.cancel) {  _ in
      print("did not buy anything")
    })
    alert.addAction(action: AABlurAlertAction(title: "Take My 💰", style: AABlurActionStyle.default) { [unowned self] _ in
      self.performSegue(withIdentifier: "shop", sender: store)
    })
    alert.blurEffectStyle = .regular
    let image = Game.shared.image(for: store)
    alert.alertImage.image = image
    alert.alertTitle.text = store.name
    alert.alertSubtitle.text = "Shopping for accessories?"
    present(alert, animated: true) {}

  }
}

