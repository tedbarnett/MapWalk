//
//  MapWalkViewController.swift
//  MapWalkSwift
//
//  Created by MyMac on 12/09/23.
//

import UIKit
import CoreLocation
import MapKit
import Photos

enum PencilType {
    case Avoid
    case Pretty
    case Shop
    case None
}

enum DrawingType {
    case EncirclingArea
    case TracingStreet
}

class MapWalkViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var btnMapType: UIButton!
    
    @IBOutlet weak var viewPenOptionAction: UIView!
    @IBOutlet weak var viewAvoid: UIView!
    @IBOutlet weak var viewPretty: UIView!
    @IBOutlet weak var viewSlider: UIView!
    @IBOutlet weak var stackSlider: UIStackView!
    
    @IBOutlet weak var viewShop: UIView!
    @IBOutlet weak var viewTopButton: UIView!
    @IBOutlet weak var btnMenu: UIButton!
    @IBOutlet weak var btnAlpha: UIButton!
    
    @IBOutlet weak var viewBottomContainer: UIView!
    @IBOutlet weak var btnAvoid: CustomButton!
    @IBOutlet weak var btnPretty: CustomButton!
    @IBOutlet weak var btnShop: CustomButton!
    @IBOutlet weak var viewBottomHeight: NSLayoutConstraint!
    
    @IBOutlet weak var sliderAlpha: UISlider!
    @IBOutlet weak var imgShape: UIImageView!
    @IBOutlet weak var imgAvoidPen: UIImageView!
    @IBOutlet weak var imgPrettyPen: UIImageView!
    @IBOutlet weak var imgShopPen: UIImageView!
    
    var selectedPencilType = PencilType.None
    
    //var drawingType = DrawingType.TracingStreet
    
    var currentMapType: MKMapType = .standard {
        didSet {
            // Update the map type
            mapView.mapType = currentMapType
            
            // Update the button image based on the map type
            let largeConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .unspecified, scale: .large)
            if currentMapType == .standard {
                btnMapType.setImage(UIImage(systemName: "map.fill", withConfiguration: largeConfig), for: .normal)
                lblMapWalk.textColor = .black
            } else {
                btnMapType.setImage(UIImage(systemName: "globe.americas.fill", withConfiguration: largeConfig), for: .normal)
                lblMapWalk.textColor = .white
            }
        }
    }
    
    var drawingType = DrawingType.EncirclingArea {
        didSet {
            // Update the button image based on the map type
            //let largeConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .unspecified, scale: .large)
            if drawingType == .EncirclingArea {
                imgShape.image = UIImage(systemName: "hexagon")
            } else {
                imgShape.image = UIImage(systemName: "line.diagonal")
            }
        }
    }
    
    private var coordinates: [CLLocationCoordinate2D] = []
    
    private var isDrawingPolygon: Bool = false
    private var canvasView: CanvasView!
    var currentMap: Map?
    var currentLocation: CLLocation?
    @IBOutlet weak var lblMapWalk: UILabel!
    var customMenu: CustomMenuView?
    var overlayView: CustomMenuOverlayView?
    var kmlParser: KMLParser?
    var openedMapURL: URL?
    
    let regionRadius: CLLocationDistance = 1000
    var park: PVPark?
    var selectedPVOverlaView: PVParkMapOverlayView?
    var selectedLocation = ""
    var locationOptions: [(name: String, coordinate: CLLocationCoordinate2D)] = [
        (name: "1776 Manhattan", coordinate: CLLocationCoordinate2D(latitude: 40.7804442, longitude: -73.9767702)),
        (name: "1660 Castello Plan", coordinate: CLLocationCoordinate2D(latitude: 40.7804442, longitude: -73.9767702)),
        (name: "1776 - Holland downtown", coordinate: CLLocationCoordinate2D(latitude: 40.7804442, longitude: -73.9767702)),
        (name: "1776 - Great Fire", coordinate: CLLocationCoordinate2D(latitude: 40.7804442, longitude: -73.9767702))
    ]
    
    
    //MARK: - Live cycle method
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupView()
    }
    
    //MARK: - Functions
    func setupView() {
        self.loadMyMap()
        self.mapView.delegate = self
        
        // Request location permission if needed
        LocationManager.shared.requestLocationPermission()
        
        // Set up location updates handler
        LocationManager.shared.locationUpdateHandler = { [weak self] location in
            // Use the updated location for your map
            self?.currentLocation = location
            self?.updateMap(with: location)
        }
        
        self.loadOverlaysOnMap()
        
        self.btnMenu.layer.cornerRadius = 10
        self.btnMenu.layer.masksToBounds = true
        self.btnAlpha.layer.cornerRadius = 10
        self.btnAlpha.layer.masksToBounds = true
        self.viewSlider.layer.cornerRadius = 10
        self.viewSlider.layer.masksToBounds = true
        self.stackSlider.layer.cornerRadius = 10
        self.stackSlider.layer.masksToBounds = true
        self.setupMenuOptions()
        
        self.viewTopButton.layer.cornerRadius = 10
        self.viewTopButton.layer.shadowColor = UIColor.black.cgColor
        self.viewTopButton.layer.shadowRadius = 1.5
        self.viewTopButton.layer.shadowOpacity = 0.3
        self.viewTopButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setMapCenter(self.locationOptions[1].coordinate, name: self.locationOptions[1].name)
            self.viewBottomContainer.roundCorners([.topLeft, .topRight], radius: 10)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleReceivedURL(_:)), name: Notification.Name("ReceivedURL"), object: nil)
    }
    
    func loadMyMap() {
        let map = CoreDataManager.shared.getMap()
        if map.count == 0 {
            CoreDataManager.shared.saveMap(mapName: "Ted's Map", isMyMap: true)
            let myMaps = CoreDataManager.shared.getMap()
            self.currentMap = myMaps.last!
        }
        else {
            for myMap in map {
                if myMap.isMyMap == true {
                    self.currentMap = myMap
                    break
                }
            }
        }
        
        let arrExcludingCategory: [MKPointOfInterestCategory] = [.cafe, .bakery, .brewery, .foodMarket, .nightlife, .restaurant, .winery, .hotel, .store]
        self.mapView.pointOfInterestFilter = MKPointOfInterestFilter(excluding: arrExcludingCategory)
    }
    
    func moveToMyCurrentMap() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.openedMapURL = nil
            self.clearMap()
            self.loadMyMap()
            self.viewBottomHeight.constant = 120
            LocationManager.shared.hasReceivedInitialLocation = false
            LocationManager.shared.startUpdatingLocation()
            self.loadOverlaysOnMap()
        }
    }
    
    func setupMenuOptions() {
        
        let option1 = UIAction(title: "Name Current Map", image: nil) { _ in
            if self.currentMap != nil {
                self.showAlertToRenameMyMap()
            }
            else {
                self.moveToMyCurrentMap()
            }
        }
        //option1.state = .off
        
        let option2 = UIAction(title: "Share Current Map", image: UIImage(systemName: "square.and.arrow.up")) { _ in
            if self.currentMap == nil {
                return
            }
            self.exportKML(sender: self.btnMenu)
        }
        
        let option3 = UIAction(title: "Shared Maps", image: nil) { _ in
            self.moveToSharedMapVC()
        }
        
        let option4 = UIAction(title: "Import A Map (or KML)", image: nil) { _ in
            self.presentFilePicker()
            
        }
        
        var menuItems: [UIMenuElement] = []
        for location in self.locationOptions {
            let menuItem = UIAction(title: location.name, handler: { [weak self] _ in
                self?.setMapCenter(location.coordinate, name: location.name)
            })
            menuItems.append(menuItem)
        }
        
        let option5 = UIMenu(title: "Map Overlay", children: menuItems)
        
        self.btnMenu.overrideUserInterfaceStyle = .dark
        self.btnMenu.showsMenuAsPrimaryAction = true
        self.btnMenu.menu = UIMenu(title: "", children: [option1, option2, option3, option4, option5])
    }
    
    func setMapCenter(_ coordinate: CLLocationCoordinate2D, name: String) {
        selectedLocation = name
        if name == "1776 Manhattan" {
            viewSlider.isHidden = true
            btnAlpha.isSelected = false
            selectedPVOverlaView = nil
            
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
            mapView.setRegion(region, animated: true)
        }
        else {
            self.loadImage(plistFilename: "ManhattanNew")
        }
    }
    
    func loadImage(plistFilename: String) {
        park = PVPark(filename: plistFilename)
        if let park = park {
            let latDelta = park.overlayTopLeftCoordinate.latitude - park.overlayBottomRightCoordinate.latitude
            // Think of a span as a TV size, measure from one corner to another
            /*let span = MKCoordinateSpan(latitudeDelta: abs(latDelta), longitudeDelta: 0.0)
            
            let region = MKCoordinateRegion(center: park.midCoordinate, span: span)
            mapView.region = region*/
            
            let region = MKCoordinateRegion(center: park.midCoordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
            mapView.setRegion(region, animated: true)
            
            loadSelectedOptions()
            //self.setCamearAngle(centerCoordinates: park.midCoordinate)
        } else {
            // Handle the case where 'park' is nil
        }
    }
    
    func loadSelectedOptions() {
        self.mapView.removeAnnotations(self.mapView.annotations)
        self.mapView.removeOverlays(self.mapView.overlays)
        self.addOverlay()
    }
    
    func addOverlay() {
        //Original image
        let overlay = PVParkMapOverlay(park: self.park!)
        self.mapView.addOverlay(overlay)
        
        
        // Coordinates
        let topLeft = self.park!.overlayTopLeftCoordinate
        let topRight = self.park!.overlayTopRightCoordinate
        let bottomLeft = self.park!.overlayBottomLeftCoordinate
        let bottomRight = self.calculateBottomRight(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft)
        
        let coordinates = [topLeft, topRight, bottomRight, bottomLeft]

        let overlays = MKPolygon(coordinates: coordinates, count: coordinates.count)

        // Add the overlay to your map
        mapView.addOverlay(overlays)
    }
    
    func calculateBottomRight(topLeft: CLLocationCoordinate2D, topRight: CLLocationCoordinate2D, bottomLeft: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // Calculate the missing bottom right corner
        let latitude = bottomLeft.latitude + (topRight.latitude - topLeft.latitude)
        let longitude = bottomLeft.longitude + (topRight.longitude - topLeft.longitude)
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func moveToSharedMapVC() {
        let vc = self.storyboard?.instantiateViewController(withIdentifier: "SharedMapViewController") as! SharedMapViewController
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .overCurrentContext
        navController.modalTransitionStyle = .crossDissolve
        navController.navigationBar.isHidden = true
        vc.delegate = self
        vc.openedMapURL = self.openedMapURL
        self.present(navController, animated: true)
    }
    
    func showAlertToRenameMyMap() {
        let alertController = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)

        // Add a text field to the alert controller
        alertController.addTextField { (textField) in
            textField.placeholder = "Type a name"
            textField.text = self.currentMap?.mapName ?? ""
        }
        
        // Add a cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        // Add an OK action
        let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
            // Access the text entered by the user
            if let textField = alertController.textFields?.first {
                if let enteredText = textField.text {
                    print("Entered text: \(enteredText)")
                    CoreDataManager.shared.renameMap(mapID: self.currentMap?.mapID ?? 0, newName: enteredText)
                    self.currentMap?.mapName = enteredText
                }
            }
        }
        alertController.addAction(okAction)

        // Present the alert controller
        self.present(alertController, animated: true, completion: nil)
    }
    
    func exportKML(sender: UIButton) {
        let kmlContent = KMLExporter.generateKML(from: self.mapView.overlays, mapView: self.mapView)
        
        if let kmlData = kmlContent.data(using: .utf8) {
            // Define the file URL with the .kml extension
            let kmlFileName = "\(self.currentMap?.mapName ?? "Ted's Map").kml"
            let kmlURL = FileManager.default.temporaryDirectory.appendingPathComponent(kmlFileName)
            
            do {
                // Write the KML data to the file URL
                try kmlData.write(to: kmlURL)
                
                // Create an activity view controller to share the file
                let activityViewController = UIActivityViewController(activityItems: [kmlURL], applicationActivities: nil)
                activityViewController.popoverPresentationController?.sourceView = self.view
                
                // Check if the device is iPad
                if let popoverPresentationController = activityViewController.popoverPresentationController {
                    popoverPresentationController.sourceView = sender
                    popoverPresentationController.sourceRect = sender.bounds
                }
                // Present the activity view controller
                self.present(activityViewController, animated: true, completion: nil)
            } catch {
                // Handle any errors that occur during file writing
                print("Error writing KML file: \(error.localizedDescription)")
            }
        }
    }
  
    private func presentFilePicker() {
        let supportedTypes: [UTType] = [UTType.data]
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func importKMLFrom(url: URL) {
        do {
            if let directoryURL = Utility.getDirectoryPath(folderName: DirectoryName.ImportedKMLFile) {
                
                let destinationURL = directoryURL.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    showAlert(title: "This KML file is already exit", message: "do you want to overwrite it?", okActionTitle: "Overwrite") { value in
                        if value == true {
                            do {
                                try FileManager.default.removeItem(at: destinationURL)
                                try FileManager.default.copyItem(at: url, to: destinationURL)
                                //Copy KML from Files or iCloud drive to app's document directory
                                self.openedMapURL = url
                                self.openKMLFileFromURL(url: destinationURL)
                                print("destinationURL: \(destinationURL)")
                            }
                            catch let error {
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
                else {
                    try FileManager.default.copyItem(at: url, to: destinationURL) //Copy KML from Files or iCloud drive to app's document directory
                    self.openKMLFileFromURL(url: destinationURL)
                    print("destinationURL: \(destinationURL)")
                }
            }
        }
        catch {
            print("Error copying video: \(error)")
        }
    }
    
    @objc func handleReceivedURL(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let url = userInfo["url"] as? URL {
            // Handle the URL here
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.openKMLFileFromURL(url: url)
            }
        }
    }
    
    func clearMap() {
        self.currentMap = nil
        self.kmlParser = nil
        for overlay in self.mapView.overlays {
            self.mapView.removeOverlay(overlay)
        }
        
        for annotation in self.mapView.annotations {
            self.mapView.removeAnnotation(annotation)
        }
    }
    
    func openKMLFileFromURL(url: URL) {
        
        self.clearMap()
        self.setupMenuOptions()
        
        self.viewBottomHeight.constant = 0
        
        kmlParser = KMLParser(url: url)
        kmlParser?.parseKML()
        
        // Add all of the MKOverlay objects parsed from the KML file to the map.
        if let overlays = kmlParser?.overlays, overlays.count > 0 {
            
            mapView.addOverlays(overlays as! [any MKOverlay])
            
            // Add all of the MKAnnotation objects parsed from the KML file to the map.
            let annotations = kmlParser?.points
            mapView.addAnnotations(annotations as! [any MKAnnotation])
            
            // Walk the list of overlays and annotations and create a MKMapRect that
            // bounds all of them and store it into flyTo.
            var flyTo = MKMapRect.null
            for overlay in overlays {
                if flyTo.isNull {
                    flyTo = (overlay as AnyObject).boundingMapRect
                } else {
                    flyTo = flyTo.union((overlay as AnyObject).boundingMapRect)
                }
            }
            
            for annotation in annotations! {
                let annotationPoint = MKMapPoint((annotation as AnyObject).coordinate)
                let pointRect = MKMapRect(x: annotationPoint.x, y: annotationPoint.y, width: 0, height: 0)
                if flyTo.isNull {
                    flyTo = pointRect
                } else {
                    flyTo = flyTo.union(pointRect)
                }
            }
            
            // Position the map so that all overlays and annotations are visible on screen.
            mapView.setVisibleMapRect(flyTo, animated: true)
        }
    }
    
    func updateMap(with location: CLLocation) {
        mapView.showsUserLocation = true
        
        // Optionally, you can set the map's region to focus on the updated location.
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: true)
    }
    
    func loadOverlaysOnMap() {
        // Load saved overlays of current map
        var overlays = CoreDataManager.shared.getOverlays()
        overlays = overlays.filter({$0.overlaysMap?.mapID == self.currentMap?.mapID})
        if overlays.count > 0 {
            for overlay in overlays {
                
                print("overlay ID: \(overlay.overlayID)")
                
                let coordinatesArray = self.convertJSONStringToCoordinates(jsonString: overlay.coordinates ?? "")
                
                let numberOfPoints = coordinatesArray.count
                
                if numberOfPoints > 2 {
                    var points: [CLLocationCoordinate2D] = []
                    for i in 0..<numberOfPoints {
                        points.append(coordinatesArray[i])
                    }
                    
                    if overlay.isLine == true {
                        let polyLine = MapPolyline(coordinates: &points, count: numberOfPoints)
                        polyLine.overlay = overlay
                        if overlay.color == "red" {
                            polyLine.strokeColor = AppColors.redColor.withAlphaComponent(0.7)
                        }
                        else if overlay.color == "blue" {
                            polyLine.strokeColor = AppColors.blueColor.withAlphaComponent(0.7)

                        }
                        else if overlay.color == "green" {
                            polyLine.strokeColor = AppColors.greenColor.withAlphaComponent(0.7)
                        }
                        DispatchQueue.main.async(execute: {
                            self.mapView.addOverlay(polyLine)
                        })
                    }
                    else {
                        let polygon = MapPolygon(coordinates: &points, count: numberOfPoints)
                        polygon.overlay = overlay
                        if overlay.color == "red" {
                            polygon.fillColor = AppColors.redColor.withAlphaComponent(0.2)
                            polygon.strokeColor = AppColors.redColor.withAlphaComponent(0.7)

                        }
                        else if overlay.color == "blue" {
                            polygon.fillColor = AppColors.blueColor.withAlphaComponent(0.2)
                            polygon.strokeColor = AppColors.blueColor.withAlphaComponent(0.7)

                        }
                        else if overlay.color == "green" {
                            polygon.fillColor = AppColors.greenColor.withAlphaComponent(0.2)
                            polygon.strokeColor = AppColors.greenColor.withAlphaComponent(0.7)
                        }
                        DispatchQueue.main.async(execute: {
                            self.mapView.addOverlay(polygon)
                        })
                    }
                    
                    if overlay.note != "" {
                        self.addBubbleAnnotation(coordinatesArray: coordinatesArray, title: overlay.note ?? "", overlayID: overlay.overlayID)
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.addLongGestureRecognizerToOverlay()
                self.addTapGestureRecognizerToOverlay()
            }
        }
    }
    
    func addBubbleAnnotation(coordinatesArray: [CLLocationCoordinate2D], title: String, overlayID: Int32) {
        // Calculate the centroid of the polygon
        var minLat = Double.greatestFiniteMagnitude
        var maxLat = -Double.greatestFiniteMagnitude
        var minLon = Double.greatestFiniteMagnitude
        var maxLon = -Double.greatestFiniteMagnitude
        
        for coordinate in coordinatesArray {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
                
        let centroidCoordinate = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

        // Add a pin annotation at the center of the polygon
        let annotation = MapPointAnnotation()
        annotation.identifier = overlayID
        annotation.coordinate = centroidCoordinate
        annotation.title = nil
        annotation.subtitle = title
        mapView.addAnnotation(annotation)
        
        //mapView.showAnnotations([annotation], animated: true)
    }
    
    func startEndDragging() {
        if isDrawingPolygon == false {
            isDrawingPolygon = true
            coordinates.removeAll()
            canvasView = CanvasView(frame: mapView.frame)
            if self.selectedPencilType == .Avoid {
                canvasView.selectedColor = AppColors.redColor
            }
            else if self.selectedPencilType == .Pretty {
                canvasView.selectedColor = AppColors.blueColor
            }
            else if self.selectedPencilType == .Shop {
                canvasView.selectedColor = AppColors.greenColor
            }
            canvasView.drawingType = self.drawingType
            canvasView.isUserInteractionEnabled = true
            canvasView.delegate = self
            view.addSubview(canvasView)
        } else {
            let numberOfPoints = coordinates.count

            if numberOfPoints > 2 {
                
                var points: [CLLocationCoordinate2D] = []
                for i in 0..<numberOfPoints {
                    points.append(coordinates[i])
                }
                
                var color = ""
                if self.selectedPencilType == .Avoid {
                    color = "red"
                }
                else if self.selectedPencilType == .Pretty {
                    color = "blue"
                }
                else if self.selectedPencilType == .Shop {
                    color = "green"
                }
                
                let savedOverlay = CoreDataManager.shared.saveOverlay(color: color, note: "", coordinates: self.convertCoordinatesToJSONString(coordinates: self.coordinates), overlaysMap: self.currentMap!, isLine: self.drawingType == .EncirclingArea ? false : true)
                
                if self.drawingType == .EncirclingArea {
                    let polygon = MapPolygon(coordinates: &points, count: numberOfPoints)
                    polygon.overlay = savedOverlay
                    if color == "red" {
                        polygon.fillColor = AppColors.redColor.withAlphaComponent(0.2)
                        polygon.strokeColor = AppColors.redColor.withAlphaComponent(0.7)
                    }
                    else if color == "blue" {
                        polygon.fillColor = AppColors.blueColor.withAlphaComponent(0.2)
                        polygon.strokeColor = AppColors.blueColor.withAlphaComponent(0.7)

                    }
                    else if color == "green" {
                        polygon.fillColor = AppColors.greenColor.withAlphaComponent(0.2)
                        polygon.strokeColor = AppColors.greenColor.withAlphaComponent(0.7)
                    }

                    DispatchQueue.main.async(execute: {
                        self.mapView.addOverlay(polygon)
                    })
                }
                else {
                    let polyLine = MapPolyline(coordinates: &points, count: numberOfPoints)
                    polyLine.overlay = savedOverlay
                    if color == "red" {
                        polyLine.strokeColor = AppColors.redColor.withAlphaComponent(0.7)
                    }
                    else if color == "blue" {
                        polyLine.strokeColor = AppColors.blueColor.withAlphaComponent(0.7)
                    }
                    else if color == "green" {
                        polyLine.strokeColor = AppColors.greenColor.withAlphaComponent(0.7)
                    }
                    DispatchQueue.main.async(execute: {
                        self.mapView.addOverlay(polyLine)
                    })
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.addLongGestureRecognizerToOverlay()
                    self.addTapGestureRecognizerToOverlay()
                }
            }
            
            self.resetCanvasView()
        }
        self.setImageTintColor()
    }
    
    func resetCanvasView() {
        self.isDrawingPolygon = false
        self.selectedPencilType = .None
        if canvasView != nil {
            canvasView.image = nil
            canvasView.removeFromSuperview()
        }
    }
    
    func convertCoordinatesToJSONString(coordinates: [CLLocationCoordinate2D]) -> String {
        var arrayCord: [[String: Any]] = []
        for cord in coordinates {
            let dic: [String: Any] = ["latitude": cord.latitude, "longitude": cord.longitude]
            arrayCord.append(dic)
        }
        var coordString: String = ""
        if let data = try? JSONSerialization.data(withJSONObject: arrayCord, options: []) {
            coordString = String(data: data, encoding: String.Encoding.utf8) ?? ""
        }
        return coordString
    }
    
    func convertJSONStringToCoordinates(jsonString: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        
        if let data = jsonString.data(using: .utf8) {
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    for jsonCoordinate in jsonArray {
                        if let latitude = jsonCoordinate["latitude"] as? CLLocationDegrees,
                            let longitude = jsonCoordinate["longitude"] as? CLLocationDegrees {
                            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                            coordinates.append(coordinate)
                        }
                    }
                }
            } catch {
                print("Error decoding JSON string to coordinates: \(error)")
            }
        }
        
        return coordinates
    }
    
    func setImageTintColor() {
        self.viewAvoid.backgroundColor = self.selectedPencilType == .Avoid ? .white : AppColors.buttonBGColor
        self.viewPretty.backgroundColor = self.selectedPencilType == .Pretty ? .white : AppColors.buttonBGColor
        self.viewShop.backgroundColor = self.selectedPencilType == .Shop ? .white : AppColors.buttonBGColor
        
        self.imgAvoidPen.tintColor = self.selectedPencilType == .Avoid ? AppColors.redColor : AppColors.grayColor
        self.imgPrettyPen.tintColor = self.selectedPencilType == .Pretty ? AppColors.blueColor : AppColors.grayColor
        self.imgShopPen.tintColor = self.selectedPencilType == .Shop ? AppColors.greenColor : AppColors.grayColor
    }
    
    //MARK: - Button actions
    @IBAction func btnAlphaAction(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        UIView.animate(withDuration: 0.3) {
            if let overlayView = self.selectedPVOverlaView {
                self.sliderAlpha.value = Float(overlayView.alpha)
                self.viewSlider.isHidden = !sender.isSelected
            }
        }
    }
    
    @IBAction func sliderAlphaAction(_ sender: UISlider) {
        if let overlayView = self.selectedPVOverlaView {
            overlayView.alpha = CGFloat(sender.value)
            overlayView.setNeedsDisplay()
            self.mapView.setNeedsLayout()
        }
    }
    
    @IBAction func btnShapeTypeAction(_ sender: Any) {
        if self.drawingType == .EncirclingArea {
            self.drawingType = .TracingStreet
        } else {
            self.drawingType = .EncirclingArea
        }
    }

    @IBAction func btnMapTypeAction(_ sender: Any) {
        DispatchQueue.main.async {
            self.btnMapType.isEnabled = false
            self.mapView.removeAnnotations(self.mapView.annotations)
            for overlay in self.mapView.overlays {
                self.mapView.removeOverlay(overlay)
            }
            
            if self.currentMapType == .standard {
                self.currentMapType = .satellite
            } else {
                self.currentMapType = .standard
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.currentLocation != nil {
                self.loadOverlaysOnMap()
                self.btnMapType.isEnabled = true
            }
        }
    }
    
    @IBAction func btnAvoidAction(_ sender: Any) {
        self.selectedPencilType = .Avoid
        self.startEndDragging()
    }
    
    @IBAction func btnPrettyAction(_ sender: Any) {
        self.selectedPencilType = .Pretty
        self.startEndDragging()
    }
    
    @IBAction func btnShopAction(_ sender: Any) {
        self.selectedPencilType = .Shop
        self.startEndDragging()
    }
    
    @IBAction func btnUndoAction(_ sender: Any) {
        var overlays = CoreDataManager.shared.getOverlays()
        overlays = overlays.filter({$0.overlaysMap?.mapID == self.currentMap?.mapID}).sorted(by: {$0.overlayID < $1.overlayID})
        
        if overlays.isEmpty {
            return
        }
        
        let overlayToDelete = overlays.last
        
        DispatchQueue.main.async {
            // Remove the last drawn shape's coordinates
            if let lastOverlay = self.mapView.overlays.last, !(lastOverlay is PVParkMapOverlay) {
                self.mapView.removeOverlay(lastOverlay)
            }
            
            // Remove the last annotation
            for annotation in self.mapView.annotations {
                if let annot = annotation as? MapPointAnnotation {
                    if annot.identifier == overlayToDelete?.overlayID {
                        self.mapView.removeAnnotation(annot)
                    }
                }
            }
            
            CoreDataManager.shared.deleteOverlay(overlayID: overlayToDelete?.overlayID ?? 0)
        }
    }
    
    @IBAction func btnCurrentLocationAction(_ sender: Any) {
        if self.kmlParser == nil {
            LocationManager.shared.hasReceivedInitialLocation = false
            LocationManager.shared.startUpdatingLocation()
        }
        else {
            self.moveToMyCurrentMap()
        }
    }
    
    @IBAction func btnMenuAction(_ sender: Any) {
        
    }
    
    //MARK: - Touch methods
    
    func touchesBegan(_ touch: UITouch) {
        let location = touch.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        coordinates.append(coordinate)
    }

    func touchesMoved(_ touch: UITouch) {
        let location = touch.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        coordinates.append(coordinate)
    }

    func touchesEnded(_ touch: UITouch) {
        let location = touch.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        coordinates.append(coordinate)
        
        if coordinates.count > 0 && self.drawingType == .EncirclingArea {
            let firstCoord = coordinates[0]
            coordinates.append(firstCoord)
        }
        self.startEndDragging()
    }
    
    //MARK: - Add Gesture recognizer
    
    func addLongGestureRecognizerToOverlay() {
        print("addLongGestureRecognizerToOverlay()")
        for overlay in mapView.overlays {
            if overlay is MapPolygon {
                let tapGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
                //let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                mapView.addGestureRecognizer(tapGesture)
            }
            else if overlay is MapPolyline {
                let tapGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
                mapView.addGestureRecognizer(tapGesture)
            }
        }
    }
    
    func addTapGestureRecognizerToOverlay() {
        print("addTapGestureRecognizerToOverlay()")
        for overlay in mapView.overlays {
            if overlay is MapPolygon {
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
                mapView.addGestureRecognizer(tapGesture)
            }
            else if overlay is MapPolyline {
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
                mapView.addGestureRecognizer(tapGesture)
            }
        }
    }
    
    @objc func handleTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        let touchPoint = gestureRecognizer.location(in: mapView)
        let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
        
        // Iterate through your overlays to check if the long press is inside any of them
        for overlay in mapView.overlays {
            if overlay is MapPolygon { // You can check for other overlay types too
                if let polygonRenderer = mapView.renderer(for: overlay) as? MKPolygonRenderer {
                    let mapPoint = MKMapPoint(coordinate)
                    let polygonViewPoint = polygonRenderer.point(for: mapPoint)
                    
                    if polygonRenderer.path.contains(polygonViewPoint) {
                        // Tap is inside this overlay
                        if let ol = overlay as? MapPolygon {
                            print(ol.overlay?.note ?? "")
                        }
                        break
                    }
                }
            }
            else if overlay is MapPolyline { // You can check for other overlay types too
                if let polygonRenderer = mapView.renderer(for: overlay) as? MKPolylineRenderer {
                    let mapPoint = MKMapPoint(coordinate)
                    let polygonViewPoint = polygonRenderer.point(for: mapPoint)
                    
                    if polygonRenderer.path.contains(polygonViewPoint) {
                        // Long press is inside this overlay
                        self.showCustomMenu(at: touchPoint, polygonOverlay: nil, polylineOverlay: overlay as? MapPolyline)
                        break
                    }
                }
            }
        }
    }
    
    @objc func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            let touchPoint = gestureRecognizer.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            // Iterate through your overlays to check if the long press is inside any of them
            for overlay in mapView.overlays {
                if overlay is MapPolygon { // You can check for other overlay types too
                    if let polygonRenderer = mapView.renderer(for: overlay) as? MKPolygonRenderer {
                        let mapPoint = MKMapPoint(coordinate)
                        let polygonViewPoint = polygonRenderer.point(for: mapPoint)
                        
                        if polygonRenderer.path.contains(polygonViewPoint) {
                            // Long press is inside this overlay
                            self.showCustomMenu(at: touchPoint, polygonOverlay: overlay as? MapPolygon, polylineOverlay: nil)
                            break
                        }
                    }
                }
                else if overlay is MapPolyline { // You can check for other overlay types too
                    if let polygonRenderer = mapView.renderer(for: overlay) as? MKPolylineRenderer {
                        let mapPoint = MKMapPoint(coordinate)
                        let polygonViewPoint = polygonRenderer.point(for: mapPoint)
                        
                        if polygonRenderer.path.contains(polygonViewPoint) {
                            // Long press is inside this overlay
                            self.showCustomMenu(at: touchPoint, polygonOverlay: nil, polylineOverlay: overlay as? MapPolyline)
                            break
                        }
                    }
                }
            }
        }
    }
    
    func showCustomMenu(at point: CGPoint, polygonOverlay: MapPolygon?, polylineOverlay: MapPolyline?) {
        if customMenu == nil {
            
            var hasNote = false
            if polygonOverlay != nil && polygonOverlay?.overlay?.note != "" {
                hasNote = true
            }
            if polygonOverlay != nil && polygonOverlay?.overlay?.note != "" {
                hasNote = true
            }
            
            // Add the overlay view
            overlayView = CustomMenuOverlayView(frame: mapView.bounds)
            overlayView?.dismissAction = {
                self.dismissCustomMenu()
            }
            mapView.addSubview(overlayView!)
            
            let menuWidth: CGFloat = 160
            let menuHeight: CGFloat = 81
            
            let initialFrame = CGRect(x: point.x, y: point.y, width: 0, height: 0)
            let expandedFrame = CGRect(x: initialFrame.origin.x, y: initialFrame.origin.y, width: menuWidth, height: menuHeight)

            if polygonOverlay != nil {
                customMenu = CustomMenuView(frame: initialFrame, delegate: self, polygonOverlay: polygonOverlay, polyLineOverlay: nil, addButtonTitle: hasNote ? "Update label" : "Add label")
            }
            else if polylineOverlay != nil {
                customMenu = CustomMenuView(frame: initialFrame, delegate: self, polygonOverlay: nil, polyLineOverlay: polylineOverlay, addButtonTitle: hasNote ? "Update label" : "Add label")
            }
            
            mapView.addSubview(customMenu!)
            
            UIView.animate(withDuration: 0.3, animations: {
                self.customMenu?.frame = expandedFrame
            }) { _ in
                // Animation completion block
                self.customMenu?.showButtons()
            }
        }
    }
    
    // Function to dismiss the custom menu
    func dismissCustomMenu() {
        customMenu?.removeFromSuperview()
        customMenu = nil
        
        overlayView?.removeFromSuperview()
        overlayView = nil
    }
    
    func isCoordinateInsidePolygon(_ coordinate: CLLocationCoordinate2D, polygon: MKPolygon) -> Bool {
        let polygonPath = CGMutablePath()
        let points = polygon.points()
        
        for i in 0..<polygon.pointCount {
            let polygonCoordinate = points[i]
            if i == 0 {
                polygonPath.move(to: CGPoint(x: polygonCoordinate.x, y: polygonCoordinate.y))
            } else {
                polygonPath.addLine(to: CGPoint(x: polygonCoordinate.x, y: polygonCoordinate.y))
            }
        }
        
        let mapPoint = MKMapPoint(coordinate)
        let boundingBox = polygonPath.boundingBox
        let mapRect = MKMapRect(x: Double(boundingBox.minX), y: Double(boundingBox.minY), width: Double(boundingBox.width), height: Double(boundingBox.height))
        
        return mapRect.contains(mapPoint)
    }
}

//MARK: - MKMapViewDelegate

extension MapWalkViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        viewSlider.isHidden = true
        btnAlpha.isSelected = false
        
        if let polygon = overlay as? MapPolygon {
            
            //let overlayPathView = MKPolygonRenderer(polygon: polygon)
            let overlayPathView = ConstantWidthPolygonRenderer(polygon: polygon)
            
            if polygon.overlay?.color == "red" {
                overlayPathView.fillColor = AppColors.redColor.withAlphaComponent(0.2)
                overlayPathView.strokeColor = AppColors.redColor.withAlphaComponent(0.7)
            }
            else if polygon.overlay?.color == "blue" {
                overlayPathView.fillColor = AppColors.blueColor.withAlphaComponent(0.2)
                overlayPathView.strokeColor = AppColors.blueColor.withAlphaComponent(0.7)
            }
            else if polygon.overlay?.color == "green" {
                overlayPathView.fillColor = AppColors.greenColor.withAlphaComponent(0.2)
                overlayPathView.strokeColor = AppColors.greenColor.withAlphaComponent(0.7)
            }
            else {
                overlayPathView.fillColor = UIColor.cyan.withAlphaComponent(0.2)
                overlayPathView.strokeColor = UIColor.blue.withAlphaComponent(0.7)
            }
            overlayPathView.lineWidth = 30
            return overlayPathView
        }
        else if let polyline = overlay as? MapPolyline {
            //let overlayPathView = MKPolylineRenderer(polyline: polyline)
            let overlayPathView = ConstantWidthPolylineRenderer(polyline: polyline)

            if polyline.overlay?.color == "red" {
                overlayPathView.strokeColor = AppColors.redColor.withAlphaComponent(0.7)
            }
            else if polyline.overlay?.color == "blue" {
                overlayPathView.strokeColor = AppColors.blueColor.withAlphaComponent(0.7)
            }
            else if polyline.overlay?.color == "green" {
                overlayPathView.strokeColor = AppColors.greenColor.withAlphaComponent(0.7)
            }
            else {
                overlayPathView.strokeColor = UIColor.blue.withAlphaComponent(0.7)
            }
            overlayPathView.lineWidth = 80
            return overlayPathView
        }
        else if self.kmlParser != nil {
            return kmlParser?.renderer(for: overlay) ?? MKOverlayRenderer()
        }
        
        if overlay is PVParkMapOverlay {
            var imgName = self.selectedLocation == "MagicMountain" ? "overlay_park" : "groundOverlay"
            switch self.selectedLocation {
            case "MagicMountain":
                imgName = "overlay_park"
            case "1660 Castello Plan":
                imgName = "groundOverlay"
            case "1776 - Holland downtown":
                imgName = "1776-Hollanddowntown"
            case "1776 - Great Fire":
                imgName = "1776-GreatFire"
            default:
                imgName = "overlay_park"
            }
            
            if let magicMountainImage = UIImage(named: imgName) {
                let overlayView = PVParkMapOverlayView(overlay: overlay, overlayImage: magicMountainImage)
                self.selectedPVOverlaView = overlayView
                return overlayView
            }
        }
        /*else if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            //renderer.fillColor = UIColor.yellow.withAlphaComponent(0.5)
            
            renderer.strokeColor = .red
            renderer.lineWidth = 2
            /*renderer.lineDashPattern = [20 as NSNumber,   // Long dash
                                        10 as NSNumber,   // Space
                                         5 as NSNumber,   // Shorter dash
                                        10 as NSNumber,   // Space
                                         1 as NSNumber,   // Dot
                                        10 as NSNumber]   // Space*/
            
            renderer.lineDashPattern = [5 as NSNumber,   // Long dash
                                        5 as NSNumber,   // Space
                                         5 as NSNumber,   // Shorter dash
                                        5 as NSNumber,   // Space
                                         1 as NSNumber,   // Dot
                                        5 as NSNumber]   // Space
            return renderer
        }*/
        
        return MKOverlayRenderer()
    }
    
    // MKMapViewDelegate method to customize annotation view
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView?
    {
        if self.kmlParser != nil {
            return kmlParser?.view(for: annotation) ?? nil
        }
            
        if !(annotation is MapPointAnnotation) {
            return nil
        }
        
        let annotationIdentifier = "AnnotationIdentifier"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: annotationIdentifier)
        
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
            annotationView!.canShowCallout = true
            annotationView!.loadCustomLines(customLines: ["\(annotation.subtitle! ?? "")"])
        }
        else {
            annotationView!.annotation = annotation
        }
        
        let pinImage = UIImage(systemName: "bubble.left.fill")?.withRenderingMode(.alwaysTemplate)
        annotationView!.image = pinImage
        annotationView?.tintColor = .white
        
        return annotationView
    }
}

extension MapWalkViewController: CustomMenuDelegate {
    // Handle the Add action
    func didSelectAdd(polygonOverlay: MapPolygon?, polyLineOverlay: MapPolyline?) {
        
        var hasNote = false
        var labelText = ""
        if polygonOverlay != nil && polygonOverlay?.overlay?.note != "" {
            hasNote = true
            labelText = polygonOverlay?.overlay?.note ?? ""
        }
        if polyLineOverlay != nil && polyLineOverlay?.overlay?.note != "" {
            hasNote = true
            labelText = polyLineOverlay?.overlay?.note ?? ""
        }
        
        // Create an alert controller
        let alertController = UIAlertController(title: hasNote ? "Update label" : "Add label", message: nil, preferredStyle: .alert)

        // Add a text field to the alert controller
        alertController.addTextField { (textField) in
            textField.placeholder = "Type a label text"
            textField.textAlignment = .left
            textField.delegate = self
            textField.clearButtonMode = .whileEditing
            if hasNote {
                textField.text = labelText
            }
        }

        // Add a cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        // Add an OK action
        let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
            // Access the text entered by the user
            if let textField = alertController.textFields?.first {
                if let enteredText = textField.text {
                    print("Entered text: \(enteredText)")
                    
                    var stringCoordinate = ""
                    var overlayID: Int32?
                    if polygonOverlay != nil {
                        CoreDataManager.shared.addUpdateNote(overlayID: polygonOverlay?.overlay?.overlayID ?? 0, note: enteredText)
                        stringCoordinate = polygonOverlay?.overlay?.coordinates ?? ""
                        overlayID = polygonOverlay?.overlay?.overlayID ?? 0
                    }
                    else {
                        CoreDataManager.shared.addUpdateNote(overlayID: polyLineOverlay?.overlay?.overlayID ?? 0, note: enteredText)
                        stringCoordinate = polyLineOverlay?.overlay?.coordinates ?? ""
                        overlayID = polyLineOverlay?.overlay?.overlayID ?? 0
                    }
                    
                    let coordinatesArray = self.convertJSONStringToCoordinates(jsonString: stringCoordinate)
                    
                    self.addBubbleAnnotation(coordinatesArray: coordinatesArray, title: enteredText, overlayID: overlayID ?? 0)
                }
            }
        }
        alertController.addAction(okAction)

        // Present the alert controller
        self.present(alertController, animated: true, completion: nil)

        dismissCustomMenu()
    }
    
    func didSelectDelete(polygonOverlay: MapPolygon?, polyLineOverlay: MapPolyline?) {
        dismissCustomMenu()
        
        if polygonOverlay != nil {
            
            DispatchQueue.main.async {
                // Remove the last drawn shape's coordinates
                for overlay in self.mapView.overlays {
                    if let ov = overlay as? MapPolygon, ov.overlay?.overlayID == polygonOverlay?.overlay?.overlayID {
                        self.mapView.removeOverlay(overlay)
                    }
                }
                
                // Remove the last annotation
                for annotation in self.mapView.annotations {
                    if let annot = annotation as? MapPointAnnotation {
                        if annot.identifier == polygonOverlay?.overlay?.overlayID {
                            self.mapView.removeAnnotation(annot)
                        }
                    }
                }
                
                CoreDataManager.shared.deleteOverlay(overlayID: polygonOverlay?.overlay?.overlayID ?? 0)
            }
        }
        else if polyLineOverlay != nil {
            
            DispatchQueue.main.async {
                // Remove the last drawn shape's coordinates
                for overlay in self.mapView.overlays {
                    if let ov = overlay as? MapPolyline, ov.overlay?.overlayID == polyLineOverlay?.overlay?.overlayID {
                        self.mapView.removeOverlay(overlay)
                    }
                }
                for annotation in self.mapView.annotations {
                    if let annot = annotation as? MapPointAnnotation {
                        if annot.identifier == polyLineOverlay?.overlay?.overlayID {
                            self.mapView.removeAnnotation(annot)
                        }
                    }
                }
                CoreDataManager.shared.deleteOverlay(overlayID: polyLineOverlay?.overlay?.overlayID ?? 0)
            }
        }
        else {
            //Nothing
        }
    }
}

//MARK: - UITextFieldDelegate
extension MapWalkViewController: UITextFieldDelegate {
    // UITextFieldDelegate method to limit character count
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: string)
        
        // Check if the new text length exceeds 140 characters
        return newText.count <= 140
    }
    
    // Selector method to handle text field changes
    @objc func textFieldDidChange(_ textField: UITextField) {
        if let text = textField.text, text.count > 140 {
            textField.text = String(text.prefix(140))
        }
    }
}

extension MapWalkViewController: SharedMapDelegate {
    func showCurrentMap() {
        self.moveToMyCurrentMap()
    }
    
    func showSelectedMapFromURL(url: URL) {
        self.openedMapURL = url
        self.openKMLFileFromURL(url: url)
    }
}

extension MapWalkViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let pickedURL = urls.first else {
            return
        }
        
        let _ = pickedURL.startAccessingSecurityScopedResource()
        // Get the file extension from the URL
        let fileExtension = pickedURL.pathExtension.lowercased()
        
        // Check the file extension or type
        if fileExtension == "kml" {
            // It's a KML file
            print("Picked KML file.")
            self.importKMLFrom(url: urls.first!)
        } else {
            // It's another type of file
            print("Picked a file with extension: \(fileExtension)")
            showAlert(title: "Invalid file", message: "Please import KML file", okActionTitle: "Ok") { result in }
        }
        
        pickedURL.stopAccessingSecurityScopedResource()
        controller.dismiss(animated: true, completion: {})
    }
        
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        //self.gotoVideoWatcherController()
    }
}

class ConstantWidthPolygonRenderer: MKPolygonRenderer {
    override func applyStrokeProperties(to context: CGContext, atZoomScale zoomScale: MKZoomScale) {
        super.applyStrokeProperties(to: context, atZoomScale: zoomScale)
        context.setLineWidth(self.lineWidth)
    }
}

class ConstantWidthPolylineRenderer: MKPolylineRenderer {
    override func applyStrokeProperties(to context: CGContext, atZoomScale zoomScale: MKZoomScale) {
        super.applyStrokeProperties(to: context, atZoomScale: zoomScale)
        context.setLineWidth(self.lineWidth)
    }
}
