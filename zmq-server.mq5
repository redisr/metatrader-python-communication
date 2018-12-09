#include <Zmq/Zmq.mqh>
#include <Trade\SymbolInfo.mqh>

extern string PROJECT_NAME = "TradeServer";
extern string ZEROMQ_PROTOCOL = "tcp";
extern string HOSTNAME = "*";
extern int REP_PORT = 5555;
extern int MILLISECOND_TIMER = 1;  // 1 millisecond

extern string t0 = "--- Trading Parameters ---";
extern int MagicNumber = 123456;

// CREATE ZeroMQ Context
Context context(PROJECT_NAME);

// CREATE ZMQ_REP SOCKET
Socket repSocket(context,ZMQ_REP);

// VARIABLES FOR LATER
uchar myData[];
ZmqMsg request;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    EventSetMillisecondTimer(MILLISECOND_TIMER);     // Set Millisecond Timer to get client socket input

    Print("[REP] Binding MT4 Server to Socket on Port " + IntegerToString(REP_PORT) + "..");

    repSocket.bind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, REP_PORT));

    /*
        Maximum amount of time in milliseconds that the thread will try to send messages 
        after its socket has been closed (the default value of -1 means to linger forever):
    */

    repSocket.setLinger(1000);  // 1000 milliseconds

    /* 
      If we initiate socket.send() without having a corresponding socket draining the queue, 
      we'll eat up memory as the socket just keeps enqueueing messages.
      
      So how many messages do we want ZeroMQ to buffer in RAM before blocking the socket?
    */

    repSocket.setSendHighWaterMark(5);     // 5 messages only.

    return(INIT_SUCCEEDED);
}
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("[REP] Unbinding MT4 Server from Socket on Port " + IntegerToString(REP_PORT) + "..");
    repSocket.unbind(StringFormat("%s://%s:%d", ZEROMQ_PROTOCOL, HOSTNAME, REP_PORT));
}
//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{   
    // Get client's response, but don't wait.
    repSocket.recv(request,true);
    
    // MessageHandler() should go here.   
    MessageHandler(request);
}
//+------------------------------------------------------------------+

void MessageHandler(ZmqMsg &localRequest)
{
    // Output object
    ZmqMsg reply;
    
    // Message components for later.
    string components[];
    
    if(localRequest.size() > 0) {
        // Get data from request   
        ArrayResize(myData, localRequest.size());
        localRequest.getData(myData);
        string dataStr = CharArrayToString(myData);
        
        // Process data
        ParseZmqMessage(dataStr, components);
        
        // Interpret data
        InterpretZmqMessage(components);
    }
}

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES TFMigrate(int tf)
{
    switch(tf)
    {
        case 0: return(PERIOD_CURRENT);
        case 1: return(PERIOD_M1);
        case 5: return(PERIOD_M5);
        case 15: return(PERIOD_M15);
        case 30: return(PERIOD_M30);
        case 60: return(PERIOD_H1);
        case 240: return(PERIOD_H4);
        case 1440: return(PERIOD_D1);
        case 10080: return(PERIOD_W1);
        case 43200: return(PERIOD_MN1);
        
        case 2: return(PERIOD_M2);
        case 3: return(PERIOD_M3);
        case 4: return(PERIOD_M4);      
        case 6: return(PERIOD_M6);
        case 10: return(PERIOD_M10);
        case 12: return(PERIOD_M12);
        case 16385: return(PERIOD_H1);
        case 16386: return(PERIOD_H2);
        case 16387: return(PERIOD_H3);
        case 16388: return(PERIOD_H4);
        case 16390: return(PERIOD_H6);
        case 16392: return(PERIOD_H8);
        case 16396: return(PERIOD_H12);
        case 16408: return(PERIOD_D1);
        case 32769: return(PERIOD_W1);
        case 49153: return(PERIOD_MN1);      
        default: return(PERIOD_CURRENT);
    }
}

//+------------------------------------------------------------------+
// Interpret Zmq Message and perform actions
void InterpretZmqMessage(string& compArray[])
{
    Print("ZMQ: Interpreting Message..");

    // 1) Trading
    // TRADE|ACTION|TYPE|SYMBOL|PRICE|SL|TP|COMMENT|TICKET
    // e.g. TRADE|OPEN|1|EURUSD|0|50|50|R-to-MetaTrader4|12345678

    // The 12345678 at the end is the ticket ID, for MODIFY and CLOSE.

    // 2) Data Requests

    // 2.1) RATES|SYMBOL   -> Returns Current Bid/Ask

    // 2.2) DATA|SYMBOL|TIMEFRAME|START_DATETIME|END_DATETIME

    // NOTE: datetime has format: D'2015.01.01 00:00'

    /*
      compArray[0] = TRADE or RATES
      If RATES -> compArray[1] = Symbol
      
      If TRADE ->
          compArray[0] = TRADE
          compArray[1] = ACTION (e.g. OPEN, MODIFY, CLOSE)
          compArray[2] = TYPE (e.g. OP_BUY, OP_SELL, etc - only used when ACTION=OPEN)
          
          // ORDER TYPES: 
          // https://docs.mql4.com/constants/tradingconstants/orderproperties
          
          // OP_BUY = 0
          // OP_SELL = 1
          // OP_BUYLIMIT = 2
          // OP_SELLLIMIT = 3
          // OP_BUYSTOP = 4
          // OP_SELLSTOP = 5
          
          compArray[3] = Symbol (e.g. EURUSD, etc.)
          compArray[4] = Open/Close Price (ignored if ACTION = MODIFY)
          compArray[5] = SL
          compArray[6] = TP
          compArray[7] = Trade Comment
    */

    int switch_action = 0;
    string volume;

    if (compArray[0] == "TRADE" && compArray[1] == "OPEN")
        switch_action = 1;
    else if (compArray[0] == "RATES")
        switch_action = 2;
    else if (compArray[0] == "TRADE" && compArray[1] == "CLOSE")
        switch_action = 3;
    else if (compArray[0] == "DATA")
        switch_action = 4;
        
    string ret = "";
    int ticket = -1;
    bool ans = false;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);    

    int price_count = 0;
    
    ZmqMsg msg("[SERVER] Processing");
    
    switch(switch_action) 
    {
        case 1: 
            repSocket.send(msg, false);
            // IMPLEMENT OPEN TRADE LOGIC HERE
            break;
        case 2: 
            ret = "N/A"; 
            if(ArraySize(compArray) > 1) 
                ret = GetCurrent(compArray[1]);
            repSocket.send(ret, false);
            break;
        case 3:
            repSocket.send(msg, false);
            // IMPLEMENT CLOSE TRADE LOGIC HERE
            
            break;
        case 4:
            ret = "";
            // Format: DATA|SYMBOL|TIMEFRAME|START_DATETIME|END_DATETIME
            price_count = CopyRates(compArray[1], TFMigrate(StringToInteger(compArray[2])),
                          StringToTime(compArray[3]), StringToTime(compArray[4]),
                          rates);
            
            if (price_count > 0)
            {              
                // Construct string of price|price|price|.. etc and send to PULL client.
                for(int i = 0; i < price_count; i++ ) {
                      ret = ret + "|" + StringFormat("%.2f,%.2f,%.2f,%.2f,%d,%d", rates[i].open, rates[i].low, rates[i].high, rates[i].close, rates[i].tick_volume, rates[i].real_volume);
                }
              
                Print("Sending: " + ret);
                repSocket.send(ret, false);
            }
            break;
        default: 
            break;
    }
}
//+------------------------------------------------------------------+
// Parse Zmq Message
void ParseZmqMessage(string& message, string& retArray[]) 
{   
    Print("Parsing: " + message);
    
    string sep = "|";
    ushort u_sep = StringGetCharacter(sep,0);
    
    int splits = StringSplit(message, u_sep, retArray);
    
    for(int i = 0; i < splits; i++) {
        Print(IntegerToString(i) + ") " + retArray[i]);
    }
}

//+------------------------------------------------------------------+
string GetVolume(string symbol, datetime start_time, datetime stop_time)
{
    long volume_array[1];
    CopyRealVolume(symbol, PERIOD_M1, start_time, stop_time, volume_array);

    return(StringFormat("%d", volume_array[0]));
}

//+------------------------------------------------------------------+
string GetCurrent(string symbol)
{
    MqlTick Last_tick;
    SymbolInfoTick(symbol,Last_tick);    
    double bid = Last_tick.bid;
    double ask = Last_tick.ask;
    MqlBookInfo bookArray[]; 
    bool getBook = MarketBookGet(symbol,bookArray);
    long buy_volume = 0;
    long sell_volume = 0;
    long buy_volume_market = 0;
    long sell_volume_market = 0;
    if (getBook) {
       for (int i =0; i < ArraySize(bookArray); i++ ) 
       {
            if (bookArray[i].type == BOOK_TYPE_SELL)
               sell_volume += bookArray[i].volume_real;
            else if (bookArray[i].type == BOOK_TYPE_BUY)
               buy_volume += bookArray[i].volume_real;
            else if (bookArray[i].type == BOOK_TYPE_BUY_MARKET)
               buy_volume_market += bookArray[i].volume_real;
            else
               sell_volume_market += bookArray[i].volume_real;
       }
    }
    long tick_volume = Last_tick.volume;
    long real_volume = Last_tick.volume_real;
    MarketBookAdd(symbol);
    return(StringFormat("%.2f,%.2f,%d,%d,%d,%d,%d,%d", bid, ask, buy_volume, sell_volume, tick_volume, real_volume, buy_volume_market, sell_volume_market));
}