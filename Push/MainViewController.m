//
//  MainViewController.m
//  Push
//
//  Created by Christopher Guess on 11/11/15.
//  Copyright © 2015 OCCRP. All rights reserved.
//

#import "MainViewController.h"
#import "FeaturedArticleTableViewCell.h"
#import "ArticlePageViewController.h"
#import "ArticleViewController.h"
#import "PushSyncManager.h"
#import <SVPullToRefresh/SVPullToRefresh.h>
#import "SearchViewController.h"
#import <Masonry/Masonry.h>
#import <MBProgressHUD/MBProgressHUD.h>
#import <AFNetworking/UIImage+AFNetworking.h>
#import "LanguageManager.h"
#import "LanguagePickerView.h"
#import "AboutViewController.h"
#import "NotificationManager.h"

#import "WebSiteViewController.h"
#import "ArticleTableViewHeader.h"
#import "SectionViewController.h"

#import "AboutBarButtonView.h"

#import "AnalyticsManager.h"
#import "PromotionsManager.h"

// These are also set in the respective nibs, so if you change it make sure you change it there too
static NSString * featuredCellIdentifier = @"FEATURED_ARTICLE_STORY_CELL";
static NSString * standardCellIdentifier = @"ARTICLE_STORY_CELL";


@interface MainViewController ()

@property (nonatomic, retain) IBOutlet UITableView * tableView;
@property (nonatomic, retain) LanguagePickerView * languagePickerView;
@property (nonatomic, retain) PromotionView * promotionView;

@property (nonatomic, retain) id articles;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupNavigationBar];
    [self setupTableView];
    
    __weak typeof(self) weakSelf = self;
    [self.tableView addPullToRefreshWithActionHandler:^{
        [AnalyticsManager logCustomEventWithName:@"Pulled To Refresh Home Screen" customAttributes:nil];
        [weakSelf loadArticles];
    }];
    
    [self loadPromotions];
    [self loadInitialArticles];
    
    // TODO: Track the user action that is important for you.
    [AnalyticsManager logContentViewWithName:@"Article List" contentType:nil contentId:nil customAttributes:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [AnalyticsManager startTimerForContentViewWithObject:self name:@"Article List Timer" contentType:nil contentId:nil customAttributes:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [AnalyticsManager endTimerForContentViewWithObject:self andName:@"Article List Timer"];
}

- (void)setupNavigationBar
{
    // Add Logo with custom barbutton item
    // Using a custom view for sizing
    UIImage * logoImage = [UIImage imageNamed:@"logo.png"];
    
    UIImageView * logoImageView = [[UIImageView alloc] initWithImage:logoImage];
    CGRect frame = logoImageView.frame;
    frame.size.height = self.navigationController.navigationBar.frame.size.height - 15;
    //get the appropriate width here
    CGFloat sizingRatio = frame.size.height / logoImage.size.height;
    frame.size.width = logoImage.size.width * sizingRatio;
    logoImageView.frame = frame;
    
    logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    
    UIBarButtonItem * occrpLogoButton = [[UIBarButtonItem alloc]
                                         initWithCustomView:logoImageView];
    
    self.navigationItem.leftBarButtonItem = occrpLogoButton;
    self.navigationController.navigationItem.leftBarButtonItem = occrpLogoButton;
    
    // Add about button
    UIBarButtonItem * aboutBarButton = [[UIBarButtonItem alloc] initWithCustomView:[[AboutBarButtonView alloc] initWithTarget:self andSelector:@selector(aboutButtonTapped)]];
    
    // Add search button
    UIBarButtonItem * searchBarButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonTapped)];
    
    // Add language button
    NSArray * barButtonItems = @[aboutBarButton, searchBarButton];
    if([LanguageManager sharedManager].availableLanguages.count > 1){
        UIBarButtonItem * languageBarButton = [[UIBarButtonItem alloc] initWithTitle:@"AД" style:UIBarButtonItemStylePlain target:self action:@selector(languageButtonTapped)];
        barButtonItems = @[languageBarButton, aboutBarButton, searchBarButton];
    }
    
    [self.navigationItem setRightBarButtonItems:barButtonItems];
    
    // Set Back button to correct language
    [self setUpBackButton];
}

// The back button needs to be translated, which requires a new button everytime.
- (void)setUpBackButton
{
    UIBarButtonItem * backButton = [[UIBarButtonItem alloc] initWithTitle:MYLocalizedString(@"Back", @"Back") style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
    
    self.navigationItem.backBarButtonItem = backButton;
}

// Just pop off the view controller
- (void)goBack
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)setupTableView
{
    self.tableView = [[UITableView alloc] init];
    self.tableView.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
    [self.view addSubview:self.tableView];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.tableView registerNib:[UINib nibWithNibName:@"ArticleTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:standardCellIdentifier];
    [self.tableView registerNib:[UINib nibWithNibName:@"FeaturedArticleTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:featuredCellIdentifier];
}

- (void)loadInitialArticles
{
    self.articles = [[PushSyncManager sharedManager] articlesWithCompletionHandler:^(NSArray *articles) {
        NSLog(@"%@", articles);
        self.articles = articles;
        [self.tableView reloadData];
        [self.tableView.pullToRefreshView stopAnimating];
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    } failure:^(NSError *error) {
        UIAlertController * alert = [UIAlertController alertControllerWithTitle:MYLocalizedString(@"ConnectionError", @"Connection Error") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:MYLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        [self.tableView.pullToRefreshView stopAnimating];
        [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    }];
    
    if(self.articles){
        [self.tableView triggerPullToRefresh];
        [self.tableView reloadData];
    } else {
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    }

}

- (void)loadArticles
{
    [[PushSyncManager sharedManager] articlesWithCompletionHandler:^(NSArray *articles) {
        NSLog(@"%@", articles);
        self.articles = articles;
        [self.tableView reloadData];
        [self.tableView.pullToRefreshView stopAnimating];
    } failure:^(NSError *error) {
        UIAlertController * alert = [UIAlertController alertControllerWithTitle:MYLocalizedString(@"ConnectionError", @"Connection Error") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {}];
        
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
        [self.tableView.pullToRefreshView stopAnimating];
    }];
}

- (void)loadPromotions
{
 
    if(self.promotionView){
        [self.promotionView removeFromSuperview];
        self.promotionView = nil;
        [self.tableView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view);
            make.right.equalTo(self.view);
            make.left.equalTo(self.view);
            make.bottom.equalTo(self.view);
        }];
    }
 
    NSArray * promotions = [PromotionsManager sharedManager].currentlyRunningPromotions;
    
    if(promotions.count == 0){
        return;
    }
    
    PromotionView * promotionView = [[PromotionView alloc] initWithPromotion:promotions[0]];
    
    if(!promotionView){
        return;
    }
    
    self.promotionView = promotionView;
    
    self.promotionView.delegate = self;
    [self.view addSubview:self.promotionView];
    
    [self.promotionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view);
        make.right.equalTo(self.view);
        make.left.equalTo(self.view);
        make.height.equalTo(@50);
    }];
    
    [self.tableView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.promotionView.mas_bottom);
        make.right.equalTo(self.view);
        make.left.equalTo(self.view);
        make.bottom.equalTo(self.view);
    }];
}

#pragma mark - PromotionViewDelegate
- (void)didTapOnPromotion:(nonnull Promotion*)promotion
{
    NSString * language = [LanguageManager sharedManager].languageShortCode;
    WebSiteViewController * webSiteController = [[WebSiteViewController alloc] initWithURL:[NSURL URLWithString:promotion.urls[language]]];
    [self.navigationController presentViewController:webSiteController animated:YES completion:nil];
//    [self.navigationController pushViewController:webSiteController animated:YES];
}

#pragma mark - Menu Button Handling

- (void)aboutButtonTapped
{
    [AnalyticsManager logContentViewWithName:@"About Tapped" contentType:@"Navigation"
                          contentId:nil customAttributes:nil];

    AboutViewController * aboutViewController = [[AboutViewController alloc] init];
    [self.navigationController pushViewController:aboutViewController animated:YES];
}

- (void)searchButtonTapped
{
    [AnalyticsManager logContentViewWithName:@"Search Tapped" contentType:@"Navigation"
                          contentId:nil customAttributes:nil];

    SearchViewController * searchViewController = [[SearchViewController alloc] init];
    [self.navigationController pushViewController:searchViewController animated:YES];
}


- (void)languageButtonTapped
{
    if(!self.languagePickerView){
        [AnalyticsManager logContentViewWithName:@"Language Button Tapped and Shown" contentType:@"Settings"
                              contentId:nil customAttributes:nil];

        [self showLanguagePicker];
    } else {
        [AnalyticsManager logContentViewWithName:@"Language Button Tapped and Hidden" contentType:@"Settings"
                              contentId:nil customAttributes:nil];

        [self hideLanguagePicker];
    }
}

#pragma mark Language Picker

- (void)languagePickerDidChooseLanguage:(NSString *)language
{
    [AnalyticsManager logContentViewWithName:@"Language Chosen" contentType:@"Settings"
                          contentId:language customAttributes:@{@"language":language}];

    NSString * oldLanguageShortCode = [LanguageManager sharedManager].languageShortCode;
    
    [[LanguageManager sharedManager] setLanguage:language];
    
    [[NotificationManager sharedManager] changeLanguage:oldLanguageShortCode
                                                     to:[LanguageManager sharedManager].languageShortCode];
    
    [self hideLanguagePicker];
    
    //Reload the view?
    [self setUpBackButton];
    [self loadArticles];
    [self loadPromotions];
    [self.view setNeedsDisplay];
}

- (void)showLanguagePicker
{
    if(self.languagePickerView){
        return;
    }
    
    self.languagePickerView = [[LanguagePickerView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, 200.0f)];
    self.languagePickerView.delegate = self;
    
    [self.view addSubview:self.languagePickerView];
    [UIView animateWithDuration:0.5f animations:^{
        CGRect frame = self.languagePickerView.frame;
        frame.origin.y = self.view.frame.size.height - frame.size.height;
        self.languagePickerView.frame = frame;
    }];
}

- (void)hideLanguagePicker
{
    if(!self.languagePickerView){
        return;
    }
    
    [UIView animateWithDuration:0.5f animations:^{
        CGRect frame = self.languagePickerView.frame;
        frame.origin.y = self.view.frame.size.height;
        self.languagePickerView.frame = frame;
    } completion:^(BOOL finished) {
        [self.languagePickerView removeFromSuperview];
        self.languagePickerView = nil;
    }];

}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat height = 100.0f;
    
    if([self.articles respondsToSelector:@selector(allKeys)]){
        if(indexPath.row == 0){
            if(indexPath.section == 0){
                height = 42.0f;
            } else {
                height = 48.0f;
            }
        }else if(indexPath.row == 1){
            height = 434.0f;
        }
    }else if(indexPath.row == 0){
        height = 434.0f;
    }
    
    return height;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:NO];
    
    NSArray * articles;
    
    if([self.articles respondsToSelector:@selector(allKeys)]){
        NSMutableArray * mutableArticles = [NSMutableArray array];
        for(NSString * sectionName in self.articles[@"categories_order"]){
            [mutableArticles addObjectsFromArray:self.articles[sectionName]];
        }
        articles = [NSArray arrayWithArray:mutableArticles];
    } else {
        articles = self.articles;
    }
    
    // If they tap on the section header
    if(indexPath.row == 0 && [self.articles respondsToSelector:@selector(allKeys)]){
        
        ArticleTableViewHeader * cell = (ArticleTableViewHeader*)[self tableView:tableView cellForRowAtIndexPath:indexPath].backgroundView;
        SectionViewController * sectionViewController = [[SectionViewController alloc]
                                                         initWithSectionTitle:self.articles[@"categories_order"][indexPath.section]
                                                         andArticles:self.articles[cell.categoryName]];
        
        [self.navigationController pushViewController:sectionViewController animated:YES];
        return;
    }

    
    ArticlePageViewController * articlePageViewController = [[ArticlePageViewController alloc] initWithArticles:articles];
    
    Article * article;
    if([self.articles respondsToSelector:@selector(allKeys)]){
        article = self.articles[self.articles[@"categories_order"][indexPath.section]][indexPath.row - 1];
    } else{
        article = self.articles[indexPath.row];
    }
    
    ArticleViewController * articleViewController = [[ArticleViewController alloc] initWithArticle:article];
    [articlePageViewController setViewControllers:@[articleViewController] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    
    [AnalyticsManager logContentViewWithName:@"Article List Item Tapped" contentType:@"Navigation"
                          contentId:article.description customAttributes:article.trackingProperties];
    
    
    [self.navigationController pushViewController:articlePageViewController animated:YES];
    
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    ArticleTableViewCell * cell;
    
    if([self.articles respondsToSelector:@selector(allKeys)]){
        
        if(indexPath.row == 0){
            ArticleTableViewHeader * header = [[ArticleTableViewHeader alloc] initWithTop:(indexPath.section == 0)];
            header.categoryName = self.articles[@"categories_order"][indexPath.section];
            UITableViewCell * cell = [[UITableViewCell alloc] init];
            cell.backgroundView = header;
            return cell;
        } else {
            NSString * sectionName = self.articles[@"categories_order"][indexPath.section];
            NSArray * articles = self.articles[sectionName];
            
            if(indexPath.row == 1){
                cell = [tableView dequeueReusableCellWithIdentifier:featuredCellIdentifier];
            } else {
                cell = [tableView dequeueReusableCellWithIdentifier:standardCellIdentifier];
            }
            
            cell.article = articles[indexPath.row - 1];
        }
    } else {
        if(indexPath.row == 0){
            cell = [tableView dequeueReusableCellWithIdentifier:featuredCellIdentifier];
        } else {
            cell = [tableView dequeueReusableCellWithIdentifier:standardCellIdentifier];
        }
        
        cell.article = self.articles[indexPath.row];
    }

    [cell setNeedsDisplay];
    return cell;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if([self.articles respondsToSelector:@selector(allKeys)]){
        return [self.articles allKeys].count - 1;
    } else {
        return 1;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Random number for testing
    if([self.articles respondsToSelector:@selector(allKeys)]){
        NSDictionary * articles = (NSDictionary*)self.articles;
        long count = [articles[self.articles[@"categories_order"][section]] count];
        if(count > 5){
            return 5 + 1;
        } else {
            return count + 1;
        }
    } else {
        return [self.articles count];
    }
}

@end
