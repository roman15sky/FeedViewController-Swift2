//
//  FeedViewController.swift
//  FixAFriend
//
//  Created by Roman on 20/03/2017.
//  Copyright © 2017 Roman. All rights reserved.
//

import UIKit
import MessageUI
import AssetsLibrary
import Photos
import Accounts
import FBAudienceNetwork
import FBSDKShareKit

class FeedViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate, FeedCellDelegate, VideoPlayerViewControllerDelegate, UIDocumentInteractionControllerDelegate, MFMailComposeViewControllerDelegate, FBNativeAdsManagerDelegate, FBNativeAdDelegate, SYPhotoBrowserDelegate, FBSDKSharingDelegate {
    
    var bLoadedView: Bool = false
    var direction: PanDirection = .undefined

    var tableViewScrollPos: CGFloat = 0.0
    
    @IBOutlet weak var m_lblWarning: UILabel!
    
    var topRefreshControl: UIRefreshControl? = nil
    var bottomRefreshControl: UIRefreshControl? = nil

    var nOffset: Int = 0
    var bLoadedMore: Bool = false

    @IBOutlet weak var m_btnEditInbox: UIButton!
    @IBOutlet weak var m_btnCamera: UIButton!
    
    @IBOutlet weak var m_tableView: UITableView!
    @IBOutlet weak var m_constraintNaviTop: NSLayoutConstraint!
    
    var arrayResult: [ArticleInfo] = []
    var arrayData: [ArticleInfo] = []

    var documentInteractionViewCon: UIDocumentInteractionController? = nil
    var adsManager: FBNativeAdsManager? = nil
    var adsCellProvider: FBNativeAdTableViewCellProvider? = nil
    
    var bShowVideoAsFullScreen: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.edgesForExtendedLayout = UIRectEdge()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIDevice.current.setValue(Int(UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
    }
    
    func canRotate() -> Void {}
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if (bLoadedView) {
            return
        }
        
        bLoadedView = true
        
        makePanGesture()
        makeUserInterface()
        loadScreenContent()
    }

    func makeUserInterface() {
        self.m_tableView.delegate = self
        self.m_tableView.dataSource = self
        
        self.m_tableView.tableFooterView = UIView()
        
        let edgeInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0)
        self.m_tableView.contentInset = edgeInsets
        self.m_tableView.scrollIndicatorInsets = edgeInsets
        
        self.m_tableView.backgroundColor = UIColor.clear
        
        self.m_tableView.estimatedRowHeight = Constants.TableViewCellHeight.FeedCell
        
        self.m_tableView.setNeedsLayout()
        self.m_tableView.layoutIfNeeded()
        
        self.bottomRefreshControl = UIRefreshControl()
        self.bottomRefreshControl!.triggerVerticalOffset = 100.0
        self.bottomRefreshControl!.addTarget(self, action: #selector(FeedViewController.loadMore), for: UIControlEvents.valueChanged)
        self.m_tableView.bottomRefreshControl = self.bottomRefreshControl
        
        self.topRefreshControl = UIRefreshControl()
        self.topRefreshControl!.addTarget(self, action: #selector(FeedViewController.refreshContent), for: .valueChanged)
        self.m_tableView.addSubview(self.topRefreshControl!)
    }
    
    func loadContent() {
        self.m_lblWarning.isHidden = true
        
        TheGlobalPoolManager.currentUser!.getArticles("-1", nOffset: nOffset) { (bSuccess, articles) in
            self.bottomRefreshControl!.endRefreshing()
            self.topRefreshControl!.endRefreshing()
            
            if (bSuccess) {
                self.arrayData.removeAll()
                if (self.nOffset == 0) {
                    self.arrayResult.removeAll()
                    self.m_tableView.reloadData()
                    //self.m_tableView.setContentOffset(CGPointZero, animated: true)
                }
                
                if (self.nOffset == 0 && articles.count == 0) {
                    self.m_lblWarning.isHidden = false
                } else {
                    self.m_lblWarning.isHidden = true
                }
                
                if (self.nOffset == 0 && articles.count > Int(Constants.Facebook.kRowStrideForAdCell)) {
                    self.loadNativeAds()
                }

                if (articles.count < 30) {
                    self.bLoadedMore = false
                } else {
                    self.nOffset += 1
                    self.bLoadedMore = true
                }
                
                self.arrayData = articles
                
                self.arrayResult.append(contentsOf: self.arrayData)
                self.m_tableView.reloadData()
                //self.insertRowAtBottom()
            } else {
                if (self.arrayResult.count == 0) {
                    self.m_lblWarning.isHidden = false
                }
            }
        }
    }
    
    func refreshContent() {
        nOffset = 0
        bLoadedMore = false
        loadContent()
    }
    
    func loadMore() {
        if (!self.bLoadedMore) {
            self.bottomRefreshControl!.endRefreshing()
            return
        }
        
        loadContent()
    }
    
    func loadScreenContent() {
        UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut, animations: {
            self.m_constraintNaviTop.constant = 0.0
            self.view.layoutIfNeeded()
            }, completion: nil)

        self.topRefreshControl!.beginRefreshing()
        self.m_tableView.setContentOffset(CGPoint(x: 0, y: -topRefreshControl!.frame.size.height), animated: true)
        
        nOffset = 0
        bLoadedMore = false
        loadContent()
    }

    func makePanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(FeedViewController.handlePanGesture(_:)))
        self.view.addGestureRecognizer(panGesture)
    }
    
    func handlePanGesture(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: pan.view!)
        
        if(self.bShowVideoAsFullScreen) {
            return
        }
        
        // do some math to translate this to a percentage based value
        var d: CGFloat = 0.0
        
        // now lets deal with different states that the gesture recognizer sends
        switch (pan.state) {
        case UIGestureRecognizerState.began:
            // set our interactive flag to true
            direction = .undefined
            
            break
            
        case UIGestureRecognizerState.changed:
            //confirm direction
            if (direction == .undefined) {
                let isVerticalGesture = fabs(translation.y) > fabs(translation.x);
                
                if (isVerticalGesture) {
                    d = translation.y / pan.view!.bounds.height
                    
                    if (translation.y > 0) {
                        direction = .down;
                        NSLog("camera view gesture moving Down");
                    } else {
                        direction = .up;
                        NSLog("camera view gesture moving Up");
                    }
                } else {
                    d = translation.x / pan.view!.bounds.width
                    if (translation.x > 0) {
                        direction = .right;
                        NSLog("camera view gesture moving right");
                    } else {
                        direction = .left;
                        NSLog("camera view gesture moving left");
                    }
                }
            }

            // update progress of the transition
            print("\(translation.y) **** \(translation.x)")
            if (direction == .right) {
                print("moving")
                TheGlobalPoolManager.mainCanvasViewCon!.moveCameraView(translation.x, completed: false)
            } else {
                print("current direction - \(direction)")
            }
            
            break
            
        default: // .Ended, .Cancelled, .Failed ...
            // return flag to false and finish the transition
            let isVerticalGesture = fabs(translation.y) > fabs(translation.x);
            
            if (isVerticalGesture) {
                d = translation.y / pan.view!.bounds.height
            } else {
                d = translation.x / pan.view!.bounds.width
            }
            
            if (abs(d) > 0.3) {
                if (direction == .right) {
                    print("moved to camera view")
                    TheGlobalPoolManager.mainCanvasViewCon!.moveCameraView(translation.x, completed: true)
                }
            } else {
                if (direction == .right) {
                    print("failed to camera view")
                    TheGlobalPoolManager.mainCanvasViewCon!.moveCameraView(-1000, completed: false)
                }
            }
            break
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func actionCamera(_ sender: AnyObject) {
        TheGlobalPoolManager.mainCanvasViewCon!.moveCameraView(0.0, completed: true)
    }

    @IBAction func actionEditInbo(_ sender: AnyObject) {
        self.navigationController?.popToViewController(TheGlobalPoolManager.mainCanvasViewCon!, animated: true)
        
        if (TheGlobalPoolManager.mainCanvasViewCon!.curDirection != .up) {
            if (TheGlobalPoolManager.mainCanvasViewCon!.curDirection == .undefined) {
                TheGlobalPoolManager.mainCanvasViewCon!.moveEditInboxView(0.0, completed: true)
            } else {
                TheGlobalPoolManager.mainCanvasViewCon!.moveCameraView(0.0, completed: true)
                
                let dispatchTime: DispatchTime = DispatchTime.now() + Double(Int64(0.36 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
                    TheGlobalPoolManager.mainCanvasViewCon!.moveEditInboxView(0.0, completed: true)
                })
            }
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - ScrollView Delegate
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        tableViewScrollPos = scrollView.contentOffset.y
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        if (tableViewScrollPos < scrollView.contentOffset.y) {
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut, animations: { 
                self.m_constraintNaviTop.constant = -64.0
                self.view.layoutIfNeeded()
                }, completion: nil)
        } else if (tableViewScrollPos > scrollView.contentOffset.y) {
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseOut, animations: {
                self.m_constraintNaviTop.constant = 0.0
                self.view.layoutIfNeeded()
                }, completion: nil)
        }
    }
    
    // MARK: - TableView Delegate
    func getCorrectIndexPathInArray(_ curIndex: Int) -> Int {
        if (self.adsCellProvider != nil) {
            return (curIndex - Int(curIndex / Int(Constants.Facebook.kRowStrideForAdCell)))
        } else {
            return curIndex
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (self.adsCellProvider != nil) {
            if (self.adsCellProvider!.isAdCell(at: indexPath, forStride: Constants.Facebook.kRowStrideForAdCell)) {
                return self.adsCellProvider!.tableView(tableView, heightForRowAt: indexPath)
            }
        }
        
        return UITableViewAutomaticDimension
    }
    
    /*
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        
        return Constants.TableViewCellHeight.FeedCell
    }
    */
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (self.adsCellProvider != nil) {
            if (self.arrayResult.count < Int(Constants.Facebook.kRowStrideForAdCell)) {
                return arrayResult.count
            } else {
                return Int(self.adsCellProvider!.adjustCount(UInt(self.arrayResult.count), forStride: Constants.Facebook.kRowStrideForAdCell))
            }
        }
        
        return arrayResult.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (self.adsCellProvider != nil) {
            if (self.adsCellProvider!.isAdCell(at: indexPath, forStride: Constants.Facebook.kRowStrideForAdCell)) {
                return self.adsCellProvider!.tableView(tableView, cellForRowAt: indexPath)
            }
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.TableViewCellID.FeedCell, for: indexPath) as! FeedCell
        
        let article = self.arrayResult[self.getCorrectIndexPathInArray(indexPath.row)]
        
        cell.delegate = self
        cell.articleInfo = article
        cell.cellIdx = self.getCorrectIndexPathInArray(indexPath.row)
        cell.loadArticleInfo()
        
        cell.selectionStyle = .none
        
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - FeedCell Delegate
    func tappedUsername(_ cell: FeedCell) {
        let articleInfo = cell.articleInfo
        
        let viewCon = self.storyboard?.instantiateViewController(withIdentifier: Constants.ViewIDs.ProfileViewController) as! ProfileViewController
        if (articleInfo!.user_id == TheGlobalPoolManager.currentUser!.id) {
            viewCon.profileMode = .me
            viewCon.currentUser = TheGlobalPoolManager.currentUser
        } else {
            viewCon.profileMode = .other
            
            let user = User()
            user.id = articleInfo!.user_id
            user.userName = articleInfo!.userName
            user.avatar = articleInfo!.avatar
            viewCon.currentUser = user
        }
        
        TheGlobalPoolManager.mainCanvasViewCon!.navigationController?.pushViewController(viewCon, animated: true)
    }
    
    func tappedPlayVideo(_ cell: FeedCell) {
        let viewCon = self.storyboard?.instantiateViewController(withIdentifier: Constants.ViewIDs.VideoPlayerViewController) as! VideoPlayerViewController
        viewCon.delegate = self
        viewCon.videoPath = cell.mediaLocalPath
        viewCon.editUserID = cell.articleInfo!.edit_user_id
        viewCon.editUserName = cell.articleInfo!.edit_user_name

        self.addChildViewController(viewCon)
        self.view.addSubview(viewCon.view)
        viewCon.didMove(toParentViewController: self)
        viewCon.view.frame = self.view.bounds
        bShowVideoAsFullScreen = true
    }
    
    // MARK: - VideoPlayerViewController Delegate
    func dismissVideoPlayerViewCon(_ viewCon: VideoPlayerViewController) {
        viewCon.willMove(toParentViewController: self)
        viewCon.view.removeFromSuperview()
        viewCon.removeFromParentViewController()
        
        bShowVideoAsFullScreen = false
    }
    
    func dismissVideoPlayerViewCon(_ viewCon: VideoPlayerViewController, userID: String, userName: String) {
        viewCon.willMove(toParentViewController: self)
        viewCon.view.removeFromSuperview()
        viewCon.removeFromParentViewController()
        
        bShowVideoAsFullScreen = false
        
        let viewCon = self.storyboard?.instantiateViewController(withIdentifier: Constants.ViewIDs.ProfileViewController) as! ProfileViewController
        if (userID == TheGlobalPoolManager.currentUser!.id) {
            viewCon.profileMode = .me
            viewCon.currentUser = TheGlobalPoolManager.currentUser
        } else {
            viewCon.profileMode = .other
            
            let user = User()
            user.id = userID
            user.userName = userName
            viewCon.currentUser = user
        }
        
        TheGlobalPoolManager.mainCanvasViewCon!.navigationController?.pushViewController(viewCon, animated: true)
    }

    func tappedPhoto(_ cell: FeedCell) {
        let photoBrowser = SYPhotoBrowser.init(imageSourceArray: [cell.m_imgThumbnail.image!], caption: cell.articleInfo!.caption, editedUserName: "Edited by \(cell.articleInfo!.edit_user_name)", delegate: self)
        photoBrowser!.initialPageIndex = UInt(0)
        photoBrowser!.pageControlStyle = .system
        photoBrowser!.userID = cell.articleInfo!.edit_user_id
        photoBrowser!.userName = cell.articleInfo!.edit_user_name
        self.present(photoBrowser!, animated: false, completion: nil)
    }
    
    // MARK: - SYPhotoBrowser Delegate
    func photoBrowser(_ photoBrowser: SYPhotoBrowser!, didTappEditUserID userID: String!, withUserName userName: String!) {
        photoBrowser.dismiss(animated: true) { 
            let viewCon = self.storyboard?.instantiateViewController(withIdentifier: Constants.ViewIDs.ProfileViewController) as! ProfileViewController
            if (userID == TheGlobalPoolManager.currentUser!.id) {
                viewCon.profileMode = .me
                viewCon.currentUser = TheGlobalPoolManager.currentUser
            } else {
                viewCon.profileMode = .other
                
                let user = User()
                user.id = userID
                user.userName = userName
                viewCon.currentUser = user
            }
            
            TheGlobalPoolManager.mainCanvasViewCon!.navigationController?.pushViewController(viewCon, animated: true)
        }
    }
    
    func tappedLikeFeed(_ cell: FeedCell, update_article: ArticleInfo, index: Int) {
        self.arrayResult[index] = update_article
    }
    
    func tappedLikesView(_ cell: FeedCell) {
        let viewCon = self.storyboard?.instantiateViewController(withIdentifier: Constants.ViewIDs.UserListViewController) as! UserListViewController
        viewCon.userListMode = .likes
        viewCon.content_id = cell.articleInfo!.id
        self.navigationController?.pushViewController(viewCon, animated: true)
    }
    
    func tappedReport(_ cell: FeedCell) {
        TheGlobalPoolManager.currentUser!.report("article", content: cell.articleInfo!.id, block: { (bSuccess) in
            InterfaceManager.showMessage(true, title: "You have reported successfully. We will review it and update again. Thank you!", bBottomPos: true)
        })
    }
    
    func tappedShareFeed(_ cell: FeedCell) {
        let hokusai = Hokusai()
        
        hokusai.addButton("Share to Facebook") {
            self.shareMediaToFB(cell.articleInfo!.media_type, mediaLink: cell.mediaLocalPath, edited_user_name: cell.articleInfo!.edit_user_name)
        }

        hokusai.addButton("Share to Twitter") {
            self.shareMediaToTwitter(cell.articleInfo!.media_type, mediaLink: cell.mediaLocalPath, edited_user_name: cell.articleInfo!.edit_user_name)
        }

        hokusai.addButton("Share to Instagram") {
            self.shareMediaToIG(cell.articleInfo!.media_type, mediaLink: cell.mediaLocalPath, edited_user_name: cell.articleInfo!.edit_user_name)
        }

        hokusai.addButton("Share to Mail") {
            self.shareMediaToEmail(cell.articleInfo!.media_type, mediaLink: cell.mediaLocalPath, edited_user_name: cell.articleInfo!.edit_user_name)
        }

        hokusai.addButton("Save to Camera Roll") {
            self.saveMediaToRoll(cell.articleInfo!.media_type, mediaLink: cell.mediaLocalPath)
        }

//        hokusai.addButton("Report") {
        hokusai.addButton("Block this user") {
            TheGlobalPoolManager.currentUser!.blockUser(cell.articleInfo!.user_id, block: { (bSuccess) in
//                InterfaceManager.showMessage(true, title: "You have reported successfully. We will review it and update again. Thank you!", bBottomPos: true)
                InterfaceManager.showMessage(true, title: "Blocked successfully!", bBottomPos: true)
                self.loadScreenContent()
            })
        }
        
        hokusai.cancelButtonTitle = "Cancel"
        
        hokusai.fontName = Constants.MainFonts.Regular
        hokusai.colorScheme = HOKColorScheme.tsubaki
        hokusai.show()
    }
    
    func tappedCommentsView(_ cell: FeedCell) {
        let viewCon = self.storyboard?.instantiateViewController(withIdentifier: Constants.ViewIDs.CommentsViewController) as! CommentsViewController
        viewCon.article_id = cell.articleInfo!.id
        self.navigationController?.pushViewController(viewCon, animated: true)
    }
    
    func tappedShowEditedUser(_ cell: FeedCell) {
        let articleInfo = cell.articleInfo
        
        let viewCon = self.storyboard?.instantiateViewController(withIdentifier: Constants.ViewIDs.ProfileViewController) as! ProfileViewController
        if (articleInfo!.edit_user_id == TheGlobalPoolManager.currentUser!.id) {
            viewCon.profileMode = .me
            viewCon.currentUser = TheGlobalPoolManager.currentUser
        } else {
            viewCon.profileMode = .other
            
            let user = User()
            user.id = articleInfo!.edit_user_id
            user.userName = articleInfo!.edit_user_name
            viewCon.currentUser = user
        }
        
        TheGlobalPoolManager.mainCanvasViewCon!.navigationController?.pushViewController(viewCon, animated: true)
    }
    
    // MARK: - Share functions
    func errorMethodFromSocial(_ error: NSError) {
        print(error.description)
        
        if (error.code == Int(ACErrorAccountNotFound.rawValue)) {
            InterfaceManager.showMessage(false, title: "Account not found. Please setup your account in settings app.", bBottomPos: true)
        } else if (error.code == Int(ACErrorAccessInfoInvalid.rawValue)) {
            InterfaceManager.showMessage(false, title: "The client's access info dictionary has incorrect or missing values.", bBottomPos: true)
        } else if (error.code == Int(ACErrorPermissionDenied.rawValue)) {
            InterfaceManager.showMessage(false, title: "The operation didn't complete because the user denied permission.", bBottomPos: true)
        } else {
            InterfaceManager.showMessage(false, title: "Account access denied.", bBottomPos: true)
        }
    }

    /*
     if (mediaType == "photo") {
     if (SLComposeViewController.isAvailableForServiceType(SLServiceTypeFacebook)) {
     let controller = SLComposeViewController(forServiceType: SLServiceTypeFacebook)
     let share_text = "This photo was edited by \(edited_user_name) on FixAFriend App on app store. Check it out here! \(Constants.Share.Link)"
     controller.setInitialText(share_text)
     controller.addURL(NSURL(string: Constants.Share.Link))
     controller.addImage(UIImage(contentsOfFile: mediaLink))
     self.presentViewController(controller, animated: true, completion: nil)
     }
     } else {
     let data = NSData(contentsOfFile: mediaLink)
     let accountStore = ACAccountStore()
     let accountType = accountStore.accountTypeWithAccountTypeIdentifier(ACAccountTypeIdentifierFacebook)
     
     let emailOptions = [ACFacebookAppIdKey: Constants.Facebook.ID,
     ACFacebookPermissionsKey: ["email"],
     ACFacebookAudienceKey: ACFacebookAudienceFriends]
     
     let options = [ACFacebookAppIdKey: Constants.Facebook.ID,
     ACFacebookPermissionsKey: ["publish_stream"],
     ACFacebookAudienceKey: ACFacebookAudienceFriends]
     
     accountStore.requestAccessToAccountsWithType(accountType, options: emailOptions as [NSObject : AnyObject], completion: { (granted, error) in
     if (granted) {
     accountStore.requestAccessToAccountsWithType(accountType, options: options as [NSObject : AnyObject], completion: { (granted, error) in
     if (granted) {
     let accounts = accountStore.accountsWithAccountType(accountType)
     if (accounts.count > 0) {
     let facebookAccount = accounts.last as! ACAccount
     
     let fbCredential = facebookAccount.credential
     let accessToken = fbCredential.oauthToken
     
     let videoURL = NSURL(string: "https://graph.facebook.com/me/videos?access_token=\(accessToken)")
     let share_text = "This video was edited by \(edited_user_name) on FixAFriend App on app store. Check it out here! \(Constants.Share.Link)"
     let params = ["title": Constants.AppName, "description": share_text]
     
     let facebookRequest = SLRequest(forServiceType: SLServiceTypeFacebook, requestMethod: .POST, URL: videoURL, parameters: params)
     facebookRequest.addMultipartData(data, withName: "source", type: "video/mp4", filename: "video_faf.mp4")
     facebookRequest.account = facebookAccount
     
     facebookRequest.performRequestWithHandler({ (responseData, urlResponse, error) in
     if (error == nil) {
     InterfaceManager.showMessage(true, title: "Shared video to Facebook successfully!", bBottomPos: true)
     } else {
     InterfaceManager.showMessage(false, title: "Failed to upload video to Facebook. Please try later!", bBottomPos: false)
     }
     })
     }
     } else {
     self.errorMethodFromSocial(error)
     }
     })
     } else {
     self.errorMethodFromSocial(error)
     }
     })
     }
 
    */
    
    func sharerDidCancel(_ sharer: FBSDKSharing!) {
        print("cancel sharing")
    }
    
    func sharer(_ sharer: FBSDKSharing!, didCompleteWithResults results: [AnyHashable: Any]!) {
        print("completed sharing \(results)")
    }
    
    func sharer(_ sharer: FBSDKSharing!, didFailWithError error: Error!) {
        print(error)
        if (error._code == 2) {
            InterfaceManager.showMessage(false, title: "You need to install Facebook app on your phone!", bBottomPos: true)
        } else {
            InterfaceManager.showMessage(false, title: "Failed to share media into Facebook!", bBottomPos: true)
        }
    }
    
    func shareMediaToFB(_ mediaType: String, mediaLink: String, edited_user_name: String) {
        if (mediaType == "photo") {
            let photo = FBSDKSharePhoto()
            photo.image = UIImage(contentsOfFile: mediaLink)
            let share_text = "This photo was edited by \(edited_user_name) on FixAFriend App on app store. Check it out here! \(Constants.Share.Link)"
            photo.caption = share_text
            photo.isUserGenerated = true
            let photoContent = FBSDKSharePhotoContent()
            photoContent.photos = [photo]
            
            DispatchQueue.main.async(execute: {
                FBSDKShareDialog.show(from: self, with: photoContent, delegate: self)
            })
        } else {
            let videoLink = URL(fileURLWithPath: mediaLink)
            var videoAssetPlaceholder:PHObjectPlaceholder!
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoLink)
                videoAssetPlaceholder = request!.placeholderForCreatedAsset
                }, completionHandler: { (success, error) in
                    if success {
                        // Saved successfully!
                        let localID = videoAssetPlaceholder.localIdentifier
                        let assetID =
                            localID.replacingOccurrences(
                                of: "/.*", with: "",
                                options: NSString.CompareOptions.regularExpression, range: nil)
                        let ext = "mp4"
                        let assetURLStr =
                            "assets-library://asset/asset.\(ext)?id=\(assetID)&ext=\(ext)"
                        
                        let video = FBSDKShareVideo()
                        video.videoURL = URL(string: assetURLStr)
                        let videoContent = FBSDKShareVideoContent()
                        videoContent.video = video
                        
                        DispatchQueue.main.async(execute: {
                            FBSDKShareDialog.show(from: self, with: videoContent, delegate: self)
                        })
                    }
                    else if let error = error {
                        print(error)
                        // Save photo failed with error
                        InterfaceManager.showMessage(false, title: "Failed to share video into Facebook!", bBottomPos: true)
                    }
                    else {
                        // Save photo failed with no error
                        InterfaceManager.showMessage(false, title: "Failed to share video into Facebook!", bBottomPos: true)
                    }
            })
        }
    }
    
    func shareMediaToTwitter(_ mediaType: String, mediaLink: String, edited_user_name: String) {
        if (mediaType == "photo") {
            if (SLComposeViewController.isAvailable(forServiceType: SLServiceTypeTwitter)) {
                let controller = SLComposeViewController(forServiceType: SLServiceTypeTwitter)
                let share_text = "This photo was edited by \(edited_user_name) on FixAFriend App on app store. Check it out here! \(Constants.Share.Link)"
                controller?.setInitialText(share_text)
                controller?.add(URL(string: Constants.Share.Link))
                controller?.add(UIImage(contentsOfFile: mediaLink))
                self.present(controller!, animated: true, completion: nil)
            }
        } else {
            let data = try? Data(contentsOf: URL(fileURLWithPath: mediaLink))
            let accountStore = ACAccountStore()
            let accountType = accountStore.accountType(withAccountTypeIdentifier: ACAccountTypeIdentifierTwitter)
            
            accountStore.requestAccessToAccounts(with: accountType, options: nil, completion: { (granted, error) in
                if (granted) {
                    let accounts = accountStore.accounts(with: accountType)
                    if ((accounts?.count)! > 0) {
                        let twitterAccount = accounts?[0]
                        let share_text = "This video was edited by \(edited_user_name) on FixAFriend App on app store. Check it out here! \(Constants.Share.Link)"

                        SocialVideoHelper.uploadTwitterVideo(data, comment: share_text, account: twitterAccount as! ACAccount, withCompletion: { (bSuccess, errorMsg) in
                            if (bSuccess) {
                                InterfaceManager.showMessage(true, title: "Shared video to Twitter successfully!", bBottomPos: true)
                            } else {
                                InterfaceManager.showMessage(false, title: errorMsg!, bBottomPos: false)
                            }
                        })
                    }
                } else {
                    self.errorMethodFromSocial(error as! NSError)
                }
            })
        }
    }
    
    func shareMediaToIG(_ mediaType: String, mediaLink: String, edited_user_name: String) {
        if (mediaType == "photo") {
            let rect = CGRect.zero
            UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, self.view.isOpaque, 0.0)
            self.view.layer.render(in: UIGraphicsGetCurrentContext()!)
            UIGraphicsEndImageContext()
            
            let imageData = UIImageJPEGRepresentation(UIImage(contentsOfFile: mediaLink)!, 1.0)
            let directoryURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let jpgPath = directoryURLs[0].path + "/" + "test.igo"
            try? imageData?.write(to: URL(fileURLWithPath: jpgPath), options: [.atomic])
            
            let igImageHookFile = URL(string: "file://\(jpgPath)")
            self.documentInteractionViewCon = self.setupController(igImageHookFile!)
            self.documentInteractionViewCon?.uti = "com.instagram.photo"
            self.documentInteractionViewCon?.presentOpenInMenu(from: rect, in: self.view, animated: true)
        } else {
            let videoFilePath = URL(fileURLWithPath: mediaLink)
            let library = ALAssetsLibrary()
            library.writeVideoAtPath(toSavedPhotosAlbum: videoFilePath, completionBlock: { (assetURL, error) in
                let escapedString = assetURL?.absoluteString.encodeURLString()
                let share_text = "This video was edited by \(edited_user_name) on FixAFriend App on app store. Check it out here! \(Constants.Share.Link)"
                let escapedCaption = share_text.encodeURLString()
                let instagramURL = URL(string: "instagram://library?AssetPath=\(escapedString!)&InstagramCaption=\(escapedCaption)")
                UIApplication.shared.openURL(instagramURL!)
            })
        }
    }
    
    func setupController(_ fileURL: URL) -> UIDocumentInteractionController {
        let interactionCon = UIDocumentInteractionController(url: fileURL)
        interactionCon.delegate = self
        
        return interactionCon
    }
    
    func saveMediaToRoll(_ mediaType: String, mediaLink: String) {
        if (mediaType == "photo") {
            let image = UIImage(contentsOfFile: mediaLink)
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image!)
                }, completionHandler: { success, error in
                    if success {
                        // Saved successfully!
                        InterfaceManager.showMessage(true, title: "Saved photo into gallery successfully!", bBottomPos: true)
                    }
                    else if let _ = error {
                        // Save photo failed with error
                        InterfaceManager.showMessage(false, title: "Failed to save photo into gallery", bBottomPos: true)
                    }
                    else {
                        // Save photo failed with no error
                        InterfaceManager.showMessage(false, title: "Failed to save photo into gallery", bBottomPos: true)
                    }
            })
        } else {
            let videoLink = URL(fileURLWithPath: mediaLink)
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoLink)
                }, completionHandler: { (success, error) in
                    if success {
                        // Saved successfully!
                        InterfaceManager.showMessage(true, title: "Saved video into gallery successfully!", bBottomPos: true)
                    }
                    else if let error = error {
                        print(error)
                        // Save photo failed with error
                        InterfaceManager.showMessage(false, title: "Failed to save video into gallery", bBottomPos: true)
                    }
                    else {
                        // Save photo failed with no error
                        InterfaceManager.showMessage(false, title: "Failed to save video into gallery", bBottomPos: true)
                    }
            })
        }
    }
    
    func shareMediaToEmail(_ mediaType: String, mediaLink: String, edited_user_name: String) {
        let picker = MFMailComposeViewController()
        if (!MFMailComposeViewController.canSendMail()) {
            InterfaceManager.showMessage(false, title: "Not available to send email!", bBottomPos: true)
            return
        }

        picker.mailComposeDelegate = self
        
        if (mediaType == "photo") {
            picker.setSubject("Send Photo")
            let share_text = "This photo was edited by \(edited_user_name) on FixAFriend App on app store. Check it out here! \(Constants.Share.Link)"
            picker.setMessageBody(share_text, isHTML: false)
            let data = UIImageJPEGRepresentation(UIImage(contentsOfFile: mediaLink)!, 1.0)
            picker.addAttachmentData(data!, mimeType: "image/jpg", fileName: "attachment")
        } else {
            picker.setSubject("Send Video")
            let share_text = "This video was edited by \(edited_user_name) on FixAFriend App on app store. Check it out here! \(Constants.Share.Link)"
            picker.setMessageBody(share_text, isHTML: false)
            let data = try? Data(contentsOf: URL(fileURLWithPath: mediaLink))
            picker.addAttachmentData(data!, mimeType: "video/mp4", fileName: "attachment")
        }
        
        DispatchQueue.main.async(execute: {
            self.present(picker, animated: true, completion: nil)
        })
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - FBNative AD Delegate
    func loadNativeAds() {
        if (self.adsCellProvider != nil) {
            self.adsCellProvider?.delegate = nil
        }
        
        self.adsCellProvider = nil
        
        if (self.adsManager == nil) {
            self.adsManager = FBNativeAdsManager(placementID: Constants.Facebook.PlacementID, forNumAdsRequested: 10)
        }
        
        self.adsManager?.delegate = self
        self.adsManager?.mediaCachePolicy = .all

        self.adsManager?.loadAds()
        print("-------- native ads calling-----------")
    }
    
    func nativeAdsLoaded() {
        print("native ads loaded ----------")
        
        let cellProvider = FBNativeAdTableViewCellProvider(manager: self.adsManager!, for: .genericHeight400)
        self.adsCellProvider = cellProvider
        self.adsCellProvider?.delegate = self
        
        self.m_tableView.reloadData()
    }
    
    func nativeAdsFailedToLoadWithError(_ error: Error) {
    }
    
    func nativeAdDidClick(_ nativeAd: FBNativeAd) {
    }
    
    func nativeAdDidFinishHandlingClick(_ nativeAd: FBNativeAd) {
    }
    
    func nativeAdWillLogImpression(_ nativeAd: FBNativeAd) {
    }
}
