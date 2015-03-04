package com.set
{
   import flash.display.Sprite;
   import net.iab.IVPAID;
   import flash.utils.Timer;
   import org.openvv.OVVAsset;
   import flash.net.NetStream;
   import flash.net.NetConnection;
   import flash.media.Video;
   import flash.net.URLVariables;
   import flash.events.TimerEvent;
   import net.iab.VPAIDEvent;
   import flash.external.ExternalInterface;
   import flash.events.Event;
   import flash.system.Security;

   public class VPAIDClient extends Sprite implements IVPAID
   {

      public function VPAIDClient()
      {
         super();
         Security.allowDomain("*");
      }

      private static const VPAID_VERSION:String = "2.0";

      protected var _adLinear:Boolean = true;

      protected var _adExpanded:Boolean = false;

      protected var _adRemainingTime:Number;

      protected var _adDuration:Number;

      protected var timer:Timer;

      protected var _initWidth:Number;

      protected var _initHeight:Number;

      protected var _adVolume:Number;

      private var _viewabilityAsset:OVVAsset;

      private var quartilesReported:Array;

      protected var ns:NetStream;

      protected var nc:NetConnection;

      protected var vid:Video;

      protected var _movieUrl:String;

      private var jsSourcePath:String = "/jssetOVV/.js";

      private var beaconPath:String = "/SetBeacon.swf";

      private var sampleRate:int = 200; //todo: pass this value to OVVAsset


      public function handshakeVersion(playerVPAIDVersion:String) : String
      {
         return VPAID_VERSION;
      }

      public function initAd(width:Number, height:Number, viewMode:String, desiredBitrate:Number, creativeData:String, environmentVars:String) : void
      {
         var adParameters:URLVariables = new URLVariables();
         adParameters.decode(creativeData);
         this._movieUrl = adParameters.MovieURL;
         this._adDuration = adParameters.MovieLength;
         this._adRemainingTime = adParameters.MovieLength;



         ExternalInterface.call("console.log","VPAIDClient:initAd: LoadOVV=" + adParameters.LoadOVV ); // debug: remove!
         var mySwfUrl:String = this.stage.loaderInfo.url;
        var swfParameters:URLVariables = new URLVariables();
        swfParameters.decode(mySwfUrl);

        if(swfParameters.jsPath) {
          this.jsSourcePath = swfParameters.jsPath;
          ExternalInterface.call("console.log","VPAIDClient:initAd: jsSourcePath=" + jsSourcePath); // debug: remove!
        }
        if(swfParameters.sampleRate) {
          this.sampleRate = swfParameters.sampleRate;
          ExternalInterface.call("console.log","VPAIDClient:initAd: sampleRate=" + sampleRate); // debug: remove!
        }

        if(swfParameters.beaconPath) {
          this.beaconPath = swfParameters.beaconPath;
          ExternalInterface.call("console.log","VPAIDClient:initAd: beaconPath=" + beaconPath); // debug: remove!
        }


        ExternalInterface.call("console.log","VPAIDClient:initAd: jsSourcePath=" + jsSourcePath  + ' and beaconPath=' + beaconPath); // todo: debug: remove!


         if(adParameters.LoadOVV)
         {
            this.loadOVV();
         }
         this._initWidth = width;
         this._initHeight = height;
         this.quartilesReported = new Array(false,false,false,false);
         this.loadAd();
      }

      public function startAd() : void
      {
         this.vid = new Video(640,400);
         addChild(this.vid);
         this.nc = new NetConnection();
         this.nc.connect(null);
         this.ns = new NetStream(this.nc);
         this.vid.attachNetStream(this.ns);
         var listener:Object = new Object();
         listener.onMetaData = function(evt:Object):void
         {
         };
         this.ns.client = listener;
         this.ns.play(this._movieUrl);
         var stamtimer:Timer = new Timer(500,1);
         stamtimer.addEventListener(TimerEvent.TIMER,this.sendAdStarted);
         stamtimer.start();
         this.timer = new Timer(1000,this._adDuration);
         this.timer.addEventListener(TimerEvent.TIMER,this.onTimer);
         this.timer.addEventListener(TimerEvent.TIMER_COMPLETE,this.timerComplete);
         this.timer.start();
      }

      public function get adLinear() : Boolean
      {
         return this._adLinear;
      }

      public function get adExpanded() : Boolean
      {
         return this._adExpanded;
      }

      public function get adRemainingTime() : Number
      {
         return this._adRemainingTime;
      }

      public function get adVolume() : Number
      {
         return this._adVolume;
      }

      public function set adVolume(value:Number) : void
      {
         this._adVolume = value;
      }

      protected function loadAd() : void
      {
         dispatchEvent(new VPAIDEvent(VPAIDEvent.AdLoaded));
      }

      protected function loadOVV() : void
      {
         var assetID:String = "ovv" + Math.floor(Math.random() * 1000000000).toString();
         ExternalInterface.call("console.log","VPAIDClient:loadOVV: assetID-" + assetID + " and beaconPath=" + beaconPath);
         this._viewabilityAsset = new OVVAsset(beaconPath,assetID);
         this._viewabilityAsset.initEventsWiring(this);

         var setJsUrl:String = jsSourcePath + "?tagtype=video&adID=" + assetID;
         ExternalInterface.call("console.log","VPAIDClient:loadOVV: target js=" + setJsUrl);
         this._viewabilityAsset.addJavaScriptResourceOnEvent(VPAIDEvent.AdImpression,setJsUrl); // sets it all up.
      }

      public function resizeAd(width:Number, height:Number, viewMode:String) : void
      {
         dispatchEvent(new VPAIDEvent(VPAIDEvent.AdExpandedChange));
      }

      protected function sendAdStarted(event:TimerEvent) : void
      {
         dispatchEvent(new VPAIDEvent(VPAIDEvent.AdStarted));
         dispatchEvent(new VPAIDEvent(VPAIDEvent.AdImpression));
      }

      protected function onTimer(pEvent:TimerEvent) : void
      {
         this._adRemainingTime--;
         this.reportQuartile();
      }

      public function stopAd() : void
      {
         this.ns.pause();
         this.ns.close();
         if(this.timer)
         {
            this.timer.stop();
            this.timer.removeEventListener(TimerEvent.TIMER,this.onTimer);
            this.timer.removeEventListener(TimerEvent.TIMER_COMPLETE,this.timerComplete);
            this.timer = null;
         }
         dispatchEvent(new VPAIDEvent(VPAIDEvent.AdVideoComplete));
         dispatchEvent(new VPAIDEvent(VPAIDEvent.AdStopped));
      }

      public function pauseAd() : void
      {
         dispatchEvent(new VPAIDEvent(VPAIDEvent.AdPaused));
      }

      public function resumeAd() : void
      {
      }

      public function expandAd() : void
      {
         dispatchEvent(new VPAIDEvent(VPAIDEvent.AdExpandedChange));
      }

      public function collapseAd() : void
      {
      }

      private function loadTag(guid:String) : void
      {
         var tagSrc:String = jsSourcePath + "?ctx=2230132&cmp=2230134&region=10204&tagtype=video&adID=" + guid;
         var tagType:String = "text/javascript";
         var func:String = "function createTag() {" + "var tag = document.createElement(\'script\');" + "tag.type = \"" + tagType + "\";" + "tag.src = \"" + tagSrc + "\";" + "document.body.insertBefore(tag, document.body.firstChild);}";
         var createTag:XML = new XML("<script><![CDATA[" + func + "]]></script>");
         ExternalInterface.call(createTag);
      }

      private function timerComplete(event:Event) : void
      {
         this.stopAd();
      }

      private function reportQuartile() : void
      {
         var eType:String = null;
         var quartileLength:Number = this._adDuration / 4;
         var currentQuartile:Number = Math.floor(this._adRemainingTime / quartileLength);
         if(!this.quartilesReported[currentQuartile])
         {
            eType = "";
            switch(currentQuartile)
            {
               case 2:
                  eType = VPAIDEvent.AdVideoFirstQuartile;
                  break;
               case 1:
                  eType = VPAIDEvent.AdVideoMidpoint;
                  break;
               case 0:
                  eType = VPAIDEvent.AdVideoThirdQuartile;
                  break;
               case 0:
                  eType = VPAIDEvent.AdVideoComplete;
                  break;
            }
            dispatchEvent(new VPAIDEvent(eType));
            this.quartilesReported[currentQuartile] = true;
         }
      }
   }
}
