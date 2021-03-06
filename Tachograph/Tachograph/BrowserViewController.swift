//
//  BrowserViewController.swift
//  Tachograph
//
//  Created by larryhou on 4/7/2017.
//  Copyright © 2017 larryhou. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import AVKit

class AssetCell:UITableViewCell
{
    @IBOutlet var ib_image:UIImageView!
    @IBOutlet var ib_time:UILabel!
    @IBOutlet var ib_progress:UIProgressView!
    @IBOutlet var ib_id:UILabel!
    @IBOutlet var ib_share:UIButton!
    
    var data:CameraModel.CameraAsset?
}

class BrowerViewController:UITableViewController, UITableViewDataSourcePrefetching,  ModelObserver, AssetManagerDelegate
{
    func asset(update name: String, location: URL)
    {
        for item in tableView.visibleCells
        {
            if let cell = item as? AssetCell, let data = cell.data, data.name == name
            {
                cell.ib_image.image = UIImage(contentsOfFile: location.absoluteString)
            }
        }
    }
    
    func asset(update name: String, progress: Float)
    {
        if !name.hasSuffix(".mp4") { return }
        
        for item in tableView.visibleCells
        {
            if let cell = item as? AssetCell, let data = cell.data, data.name == name
            {
                cell.ib_progress.progress = progress
                if progress == 1.0
                {
                    cell.ib_progress.isHidden = true
                }
                else
                {
                    cell.ib_progress.isHidden = false
                }
                cell.ib_share.isHidden = !cell.ib_progress.isHidden
            }
        }
    }
    
    var OrientationContext:String?
    
    func model(assets: [CameraModel.CameraAsset], type: CameraModel.AssetType)
    {
        if type == .route && self.videoAssets.count != assets.count
        {
            loading = false
            if let index = self.focusIndex
            {
                let data = videoAssets[index.row]
                for i in 0..<assets.count
                {
                    if assets[i].name == data.name
                    {
                        self.focusIndex = IndexPath(row: i, section: index.section)
                    }
                }
            }
            
            videoAssets = assets
            tableView.reloadData()
            
            if let index = self.focusIndex
            {
                if let cell = tableView.cellForRow(at: index)
                {
                    var frame = cell.superview!.convert(cell.frame, to: view)
                    frame.size.height = sizeCell.height
                    UIView.animate(withDuration: 0.25)
                    {
                        self.videoController?.view.frame = frame
                    }
                } 
            }
        }
        
        loadingIndicator.stopAnimating()
        tableView.tableFooterView = nil
    }
    
    var videoAssets:[CameraModel.CameraAsset] = []
    var formatter:DateFormatter!
    
    var loadingIndicator:UIActivityIndicatorView!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        videoAssets = CameraModel.shared.routeVideos
        AssetManager.shared.delegate = self
        
        formatter = DateFormatter()
        formatter.dateFormat = "HH:mm/MM-dd"
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(orientationUpdate), name: .UIDeviceOrientationDidChange, object: nil)
        
        loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        loadingIndicator.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        loadingIndicator.hidesWhenStopped = false
    }
    
    var sizeCell:CGSize = CGSize()
    @objc func orientationUpdate()
    {
        sizeCell = CGSize(width: view.frame.width, height: view.frame.width / 16 * 9)
        if let controller = self.videoController
        {
            tableView.beginUpdates()
            tableView.endUpdates()
            
            let barController = self.parent as! UITabBarController
            
            self.frameVideo.size = sizeCell
            controller.view.frame = self.frameVideo
            let orientation = UIDevice.current.orientation
            if orientation == .landscapeRight || orientation == .landscapeLeft
            {
                if let index = self.focusIndex
                {
                    tableView.scrollToRow(at: index, at: .top, animated: true)
                }
                
                barController.tabBar.isHidden = true
            }
            else
            {
                barController.tabBar.isHidden = false
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath])
    {
        for index in indexPaths
        {
            if let cell = tableView.cellForRow(at: index) as? AssetCell
            {
                if let data = cell.data
                {
                    AssetManager.shared.load(url: data.icon)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        if focusIndex == indexPath
        {
            return sizeCell.height
        }
        
        return 70
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return videoAssets.count
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        if indexPath.row == videoAssets.count - 1
        {
            if tableView.tableFooterView == nil
            {
                tableView.tableFooterView = loadingIndicator
            }
            
            loadingIndicator.startAnimating()
            
            loading = true
            CameraModel.shared.fetchRouteVideos()
        }
    }
    
    var videoController:AVPlayerViewController?
    var focusIndex:IndexPath?, frameVideo:CGRect!
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        focusIndex = indexPath
        
        tableView.beginUpdates()
        tableView.endUpdates()
        
        #if NATIVE_DEBUG
        guard let url = URL(string: "http://\(LIVE_SERVER.addr):8080/sample.mp4") else {return}
        #else
        let data = videoAssets[indexPath.row]
        guard let url = URL(string: data.url) else {return}
        #endif
        
        if let cell = tableView.cellForRow(at: indexPath)
        {
            frameVideo = cell.superview!.convert(cell.frame, to: self.view)
            frameVideo.size.height = sizeCell.height
            
            if self.videoController == nil
            {
                videoController = AVPlayerViewController()
                videoController?.view.frame = frameVideo
                view.addSubview(videoController!.view)
                videoController?.view.isHidden = true
            }
            else
            {
                videoController?.player?.pause()
            }
            
            UIView.setAnimationCurve(.easeInOut)
            UIView.animate(withDuration: 0.25, animations:
            { [unowned self] in
                self.videoController!.view.isHidden = false
                self.videoController!.view.frame = self.frameVideo
            }, completion:
            { [unowned self] (flag) in
                self.videoController!.player = AVPlayer(url: url)
                self.videoController!.player?.automaticallyWaitsToMinimizeStalling = false
            })
        }
    }
    
    var loading = false
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "AssetCell") as? AssetCell
        {
            let data = videoAssets[indexPath.row]
            cell.ib_time.text = formatter.string(from: data.timestamp)
            cell.ib_progress.isHidden = true
            cell.ib_progress.progress = 0.0
            cell.ib_id.text = data.id
            cell.data = data
            if let url = AssetManager.shared.get(url: data.icon)
            {
                cell.ib_image.image = UIImage(contentsOfFile: url.absoluteString)
            }
            cell.ib_share.isHidden = AssetManager.shared.has(url: data.url)
            return cell
        }
        
        return UITableViewCell()
    }
}
