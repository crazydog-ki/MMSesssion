// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#import "MMMainViewController.h"
#import "MMCameraViewController.h"
#import "MMAVFDViewController.h"
#import "MMAVTBViewController.h"

@interface MMMainViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray<NSString *> *data;
@property (nonatomic, weak) UITableView *tableView;
@end

@implementation MMMainViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"MMSession";
    self.data = @[@"Camera",
                  @"AVFD",
                  @"FFmpeg & AVTB",
                  @"AV-Multi",
                  @"AV-Filter"];
    
    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    tableView.backgroundColor = UIColor.blackColor;
    tableView.scrollEnabled = NO;
    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    tableView.tableFooterView.backgroundColor = UIColor.blackColor;
    [self.view addSubview:tableView];
    tableView.dataSource = self;
    tableView.delegate = self;
    self.tableView = tableView;
}

#pragma mark - UITableViewDataSource & UITableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.data.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *indentifier = @"mmsession_cell_indentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:indentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:indentifier];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = self.data[indexPath.row];
    cell.textLabel.textAlignment = NSTextAlignmentCenter;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    cell.backgroundColor = kMMColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self _transAnimation];
    
    NSString *selectedTex = self.data[indexPath.row];
    if ([selectedTex isEqualToString:@"Camera"]) {
        [self.navigationController pushViewController:[[MMCameraViewController alloc] init] animated:NO];
    } else if ([selectedTex isEqualToString:@"AVFD"])  {
        [self.navigationController pushViewController:[[MMAVFDViewController alloc] init] animated:NO];
    } else if ([selectedTex isEqualToString:@"FFmpeg & AVTB"]) {
        [self.navigationController pushViewController:[[MMAVTBViewController alloc] init] animated:NO];
    }
}

#pragma mark - Private
- (void)_transAnimation {
    CATransition *animation = [CATransition animation];
    [animation setDuration:0.5f];
    [animation setType:kCATransitionFade];
    [animation setSubtype:kCATransitionFromTop];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault]];
    [self.navigationController.view.layer addAnimation:animation forKey:nil];
}
@end
