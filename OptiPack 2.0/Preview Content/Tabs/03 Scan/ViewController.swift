/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import Foundation
import MachO
import Metal
import MetalKit
import SwiftUI
import UIKit
import ZIPFoundation

final class ViewController: UIViewController, ARSessionDelegate {
  private let isUIEnabled = true
  private let confidenceControl = UISegmentedControl(items: ["Low", "Medium", "High"])
  private let rgbRadiusSlider = UISlider()

  private let session = ARSession()
  private var renderer: Renderer!
  private var isScanning = false

  private let rotationPromptLabel: UILabel = {
    let label = UILabel()
    label.text = "Rotate device to landscape for best scanning"
    label.textColor = .white
    label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    label.textAlignment = .center
    label.font = UIFont.boldSystemFont(ofSize: 16)
    label.layer.cornerRadius = 8
    label.layer.masksToBounds = true
    label.numberOfLines = 0
    label.isHidden = true
    return label
  }()

  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .portrait
  }

  override var shouldAutorotate: Bool {
    return false
  }

  @objc private func deviceOrientationDidChange() {
    updateRotationPrompt()
  }

  private func updateRotationPrompt() {
    let isLandscapeRight = UIDevice.current.orientation == .landscapeRight
    rotationPromptLabel.isHidden = isLandscapeRight || !isScanning
  }

  func logMemoryUsage(tag: String = "") {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let kerr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }

    if kerr == KERN_SUCCESS {
      let usedMB = info.resident_size / 1024 / 1024
      print("[MEM] \(tag): Used Memory = \(usedMB) MB")
    } else {
      print("[MEM] \(tag): Error getting memory info")
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view = MTKView()

    view.addSubview(rotationPromptLabel)
    rotationPromptLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      rotationPromptLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      rotationPromptLabel.topAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
      rotationPromptLabel.leadingAnchor.constraint(
        greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
      rotationPromptLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: view.trailingAnchor, constant: -20),
    ])

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(deviceOrientationDidChange),
      name: UIDevice.orientationDidChangeNotification,
      object: nil)

    toggleCameraButton.setTitle("Toggle Camera", for: .normal)
    toggleCameraButton.addTarget(self, action: #selector(toggleCameraFeed), for: .touchUpInside)
    toggleCameraButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(toggleCameraButton)

    NSLayoutConstraint.activate([
      toggleCameraButton.topAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      toggleCameraButton.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
    ])

    guard let device = MTLCreateSystemDefaultDevice() else {
      print("Metal is not supported on this device")
      return

    }

    session.delegate = self

    // Check if the view is an MTKView and set it up
    guard let mtkView = view as? MTKView else {
      print("Error: The view is not an MTKView")
      return
    }

    mtkView.device = device
    mtkView.backgroundColor = UIColor.clear
    // We need this to enable depth test
    mtkView.depthStencilPixelFormat = .depth32Float
    mtkView.contentScaleFactor = 1
    mtkView.delegate = self

    let configuration = ARWorldTrackingConfiguration()
    if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
      configuration.frameSemantics = .sceneDepth
    } else {
      print("Scene depth is not supported on this device.")
    }

    configuration.environmentTexturing = .automatic
    if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
      configuration.sceneReconstruction = .mesh
    }

    if renderer == nil {
      renderer = Renderer(session: session, metalDevice: device, renderDestination: mtkView)
    }

    if mtkView.bounds.size.width > 0 && mtkView.bounds.size.height > 0 {
      renderer.drawRectResized(size: mtkView.bounds.size)
    } else {
      print("Error: Invalid view size, delaying renderer initialization")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        if let size = self?.view.bounds.size, size.width > 0 && size.height > 0 {
          self?.renderer?.drawRectResized(size: size)
        } else {
          print("Error: View size is still invalid")
        }
      }
    }

    // Confidence control setup
    confidenceControl.backgroundColor = .white
    confidenceControl.selectedSegmentIndex = renderer?.confidenceThreshold ?? 0  // Use optional chaining for renderer
    confidenceControl.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)
    // RGB Radius control
    rgbRadiusSlider.minimumValue = 0
    rgbRadiusSlider.maximumValue = 1.5
    rgbRadiusSlider.isContinuous = true
    rgbRadiusSlider.value = renderer.rgbRadius
    rgbRadiusSlider.addTarget(self, action: #selector(viewValueChanged), for: .valueChanged)

    let stackView = UIStackView(arrangedSubviews: [confidenceControl, rgbRadiusSlider])
    stackView.isHidden = !isUIEnabled
    stackView.translatesAutoresizingMaskIntoConstraints = false
    stackView.axis = .vertical
    stackView.spacing = 20
    view.addSubview(stackView)
    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
    ])

    // Setup a save button
    let saveButton = UIButton(
      type: .system,
      primaryAction: UIAction(
        title: "Save",
        handler: { _ in
          self.renderer.savePointsToFile()
          if let cameraImage = self.renderer.currentCameraImage() {
            self.uploadScreenshot(image: cameraImage)
            print("✅ Captured camera image.")
          } else {
            print("⚠️ Could not capture camera image.")
          }
        }))
    saveButton.setTitle("Save", for: .normal)
    saveButton.layer.cornerRadius = 25
    saveButton.layer.masksToBounds = true
    saveButton.backgroundColor = .white
    saveButton.tintColor = .systemTeal
    saveButton.translatesAutoresizingMaskIntoConstraints = false
    saveButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
    saveButton.widthAnchor.constraint(equalToConstant: 50).isActive = true

    let scanButton = UIButton(type: .system)
    scanButton.setTitle("Scan", for: .normal)
    scanButton.layer.cornerRadius = 25
    scanButton.layer.masksToBounds = true
    scanButton.backgroundColor = .white
    scanButton.tintColor = .systemTeal
    scanButton.translatesAutoresizingMaskIntoConstraints = false
    scanButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
    scanButton.widthAnchor.constraint(equalToConstant: 50).isActive = true

    scanButton.addAction(
      UIAction { [weak self, weak scanButton] _ in
        guard let self = self, let button = scanButton else { return }
        self.toggleScanning(button)
      }, for: .touchUpInside)

    let resetButton = createRoundButton(title: "Reset") {
      self.renderer.resetScanning()
    }

    let buttonStack = UIStackView(arrangedSubviews: [scanButton, resetButton, saveButton])
    buttonStack.axis = .vertical
    buttonStack.spacing = 12
    buttonStack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(buttonStack)

    NSLayoutConstraint.activate([
      buttonStack.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
      buttonStack.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
    ])

  }

  @objc func toggleCameraFeed() {
    renderer.showCameraFeed.toggle()
    let title = renderer.showCameraFeed ? "Hide Camera" : "Show Camera"
    toggleCameraButton.setTitle(title, for: .normal)

    if let mtkView = view as? MTKView {
      mtkView.setNeedsDisplay()
    }
  }

  func createRoundButton(title: String, action: @escaping () -> Void) -> UIButton {
    let button = UIButton(
      type: .system, primaryAction: UIAction(title: title, handler: { _ in action() }))
    button.setTitle(title, for: .normal)
    button.backgroundColor = UIColor.systemBackground
    button.setTitleColor(.systemTeal, for: .normal)
    button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.widthAnchor.constraint(equalToConstant: 50).isActive = true
    button.heightAnchor.constraint(equalToConstant: 50).isActive = true
    button.layer.cornerRadius = 25
    button.clipsToBounds = true
    return button
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // Create a world-tracking configuration, and
    // enable the scene depth frame-semantic.
    let configuration = ARWorldTrackingConfiguration()
    configuration.frameSemantics = .sceneDepth
    configuration.worldAlignment = .gravityAndHeading
    // Run the view's session
    session.run(configuration)

    // The screen shouldn't dim during AR experiences.
    UIApplication.shared.isIdleTimerDisabled = true
  }

  @objc
  private func viewValueChanged(view: UIView) {
    switch view {

    case confidenceControl:
      renderer.confidenceThreshold = confidenceControl.selectedSegmentIndex

    case rgbRadiusSlider:
      renderer.rgbRadius = rgbRadiusSlider.value

    default:
      break
    }
  }

  @objc private func toggleScanning(_ sender: UIButton) {
    isScanning.toggle()

    // Update button title for compact round style
    sender.setTitle(isScanning ? "Stop" : "Scan", for: .normal)

    renderer.isScanning = isScanning
    updateRotationPrompt()
  }

  let toggleCameraButton = UIButton(type: .system)

  // Auto-hide the home indicator to maximize immersion in AR experiences.
  override var prefersHomeIndicatorAutoHidden: Bool {
    return true
  }

  // Hide the status bar to maximize immersion in AR experiences.
  override var prefersStatusBarHidden: Bool {
    return true
  }

  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    logMemoryUsage(tag: "DidUpdate")
    // print("ARSession updated. Camera position:", frame.camera.transform)
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    // Present an error message to the user.
    guard error is ARError else { return }
    let errorWithInfo = error as NSError
    let messages = [
      errorWithInfo.localizedDescription,
      errorWithInfo.localizedFailureReason,
      errorWithInfo.localizedRecoverySuggestion,
    ]
    let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
    DispatchQueue.main.async {
      // Present an alert informing about the error that has occurred.
      let alertController = UIAlertController(
        title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
      let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
        alertController.dismiss(animated: true, completion: nil)
        if let configuration = self.session.configuration {
          self.session.run(
            configuration,
            options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
        }
      }
      alertController.addAction(restartAction)
      self.present(alertController, animated: true, completion: nil)
    }
  }

  public func uploadScreenshot(image: UIImage) {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
      print("❌ Could not convert UIImage to JPEG")
      return
    }

    let base = UserDefaults.standard.string(forKey: "imageDetectionURL") ?? ""
    let detectionPath = UserDefaults.standard.string(forKey: "detectionPath") ?? "/detect"

    let fullURLString =
      base.hasSuffix("/") || detectionPath.hasPrefix("/")
      ? base + detectionPath
      : base + "/" + detectionPath

    guard let url = URL(string: fullURLString) else {
      print("❌ Invalid image detection URL")
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let boundary = UUID().uuidString
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append(
      "Content-Disposition: form-data; name=\"file\"; filename=\"screenshot.jpg\"\r\n".data(
        using: .utf8)!)
    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
    body.append(imageData)
    body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

    let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
      if let error = error {
        print("❌ Upload failed: \(error)")
        return
      }

      guard let data = data else {
        print("❌ No data received")
        return
      }

      let fileManager = FileManager.default
      let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
      let zipURL = documents.appendingPathComponent("detection_result.zip")
      let unzipDestination = documents.appendingPathComponent("ObjectsDetected")

      do {
        // Save the ZIP file
        try data.write(to: zipURL)
        print("✅ Saved ZIP to: \(zipURL.path)")

        // Remove old folder if it exists
        if fileManager.fileExists(atPath: unzipDestination.path) {
          try fileManager.removeItem(at: unzipDestination)
        }

        // Unzip
        try fileManager.createDirectory(at: unzipDestination, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: zipURL, to: unzipDestination)
        print("✅ Unzipped to: \(unzipDestination.path)")
      } catch {
        print("❌ Error saving or unzipping ZIP: \(error)")
      }
    }

    task.resume()
  }

}

// MARK: - MTKViewDelegate

extension ViewController: MTKViewDelegate {
  // Called whenever view changes orientation or layout is changed
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    renderer.drawRectResized(size: size)
  }

  // Called whenever the view needs to render
  func draw(in view: MTKView) {
    renderer.draw()
  }
}

// MARK: - RenderDestinationProvider

protocol RenderDestinationProvider {
  var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
  var currentDrawable: CAMetalDrawable? { get }
  var colorPixelFormat: MTLPixelFormat { get set }
  var depthStencilPixelFormat: MTLPixelFormat { get set }
  var sampleCount: Int { get set }
}

extension MTKView: RenderDestinationProvider {

}
