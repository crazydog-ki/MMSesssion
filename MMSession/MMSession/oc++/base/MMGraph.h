// Created by crazydog-ki
// Email  : jxyou.ki@gmail.com
// Github : https://github.com/crazydog-ki

#include <string>
#import "MMFFParser.h"
#import "MMVTDecoder.h"
#import "MMPreviewUnit.h"
#import "MMDriveUnit.h"
#import "MMFFDecoder.h"
#import "MMAudioPlayer.h"
#import "MMSampleData.h"
#import "MMUnitContext.h"

using MMSelfDriveCmd = function<void(shared_ptr<MMSampleData>)>;

struct MMGraphConfig {
    string videoPath;
    UIView *view;
    CGRect presentRect;
    CGRect viewRect;
};

class MMGraph {
public:
    MMGraph(MMGraphConfig config);
    ~MMGraph();
    void drive();
    void destroy();
private:
    MMGraphConfig m_config;
    shared_ptr<MMUnitContext> m_unitCtx;
    
    MMSelfDriveCmd m_videoDriveCmd;
    MMSelfDriveCmd m_audioDriveCmd;
    dispatch_queue_t m_videoDriveQueue;
    dispatch_queue_t m_audioDriveQueue;
    
    shared_ptr<MMFFParser> m_ffVideoParser;
    shared_ptr<MMVTDecoder> m_vtDecoder;
    shared_ptr<MMPreviewUnit> m_previewUnit;
    shared_ptr<MMDriveUnit> m_driveUnit;
    
    shared_ptr<MMFFParser> m_ffAudioParser;
    shared_ptr<MMFFDecoder> m_ffAudioDecoder;
    shared_ptr<MMAudioPlayer> m_audioPlayer;
    
    void _buildUnitsConn();
    void _configSharedCtx();
    void _configMsg();
    void _setupParser();
    void _setupDecoder();
    void _setupDriveUnit();
    void _setupPreview();
    void _setupAudioPlayer();
    
    bool m_stopFlag = false;
};
