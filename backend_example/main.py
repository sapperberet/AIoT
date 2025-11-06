"""
Smart Home AI Chat Agent Backend
Simple FastAPI server for AI-powered smart home chat

Author: GitHub Copilot
Date: November 2025
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional, Dict
import uvicorn
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Smart Home AI Agent",
    description="AI-powered chat agent for smart home control",
    version="1.0.0"
)

# Add CORS middleware to allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory storage (use database in production)
chat_history: Dict[str, List[dict]] = {}

# Pydantic models
class ChatMessage(BaseModel):
    message: str
    user_id: str
    timestamp: str

class ChatResponse(BaseModel):
    response: str
    message: Optional[str] = None

class HistoryResponse(BaseModel):
    messages: List[dict]

# Health check endpoint
@app.get("/health")
async def health_check():
    """Check if the server is running"""
    logger.info("Health check requested")
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

# Main chat endpoint
@app.post("/api/chat", response_model=ChatResponse)
async def chat(msg: ChatMessage):
    """
    Process chat message and return AI response
    
    Args:
        msg: ChatMessage containing user message, user_id, and timestamp
        
    Returns:
        ChatResponse with AI-generated response
    """
    try:
        logger.info(f"User {msg.user_id}: {msg.message}")
        
        # Store user message in history
        if msg.user_id not in chat_history:
            chat_history[msg.user_id] = []
        
        chat_history[msg.user_id].append({
            "id": f"msg_{len(chat_history[msg.user_id])}",
            "content": msg.message,
            "is_user": True,
            "timestamp": msg.timestamp
        })
        
        # Generate AI response based on message content
        user_message = msg.message.lower()
        response = generate_response(user_message, msg.user_id)
        
        # Store AI response in history
        chat_history[msg.user_id].append({
            "id": f"msg_{len(chat_history[msg.user_id])}",
            "content": response,
            "is_user": False,
            "timestamp": datetime.now().isoformat()
        })
        
        logger.info(f"AI Response: {response[:50]}...")
        
        # Return response in both 'response' and 'message' fields for compatibility
        return ChatResponse(response=response, message=response)
        
    except Exception as e:
        logger.error(f"Error processing chat message: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

def generate_response(user_message: str, user_id: str) -> str:
    """
    Generate smart responses based on message content
    
    Args:
        user_message: User's message in lowercase
        user_id: User identifier
        
    Returns:
        AI-generated response string
    """
    
    # Greetings
    if any(word in user_message for word in ["hello", "hi", "hey", "greetings"]):
        return "👋 Hello! I'm your smart home AI assistant. I can help you control devices, create automations, monitor energy, and answer questions about your home. How can I assist you today?"
    
    # Device status queries
    elif any(word in user_message for word in ["status", "device", "online", "offline", "check"]):
        return """✅ **Device Status Update**

All your smart home devices are online and functioning normally:

🏠 **Living Room**
  • Smart Light #1 - ON (80% brightness)
  • Smart Light #2 - ON (60% brightness)
  • Motion Sensor - Active

🛏️ **Bedroom**
  • Smart Light - OFF
  • Temperature Sensor - 22°C

🌡️ **Thermostat**
  • Status: Active
  • Current: 21°C
  • Target: 22°C
  • Mode: Auto

Everything is working perfectly! Any specific device you'd like to check?"""
    
    # Automation queries
    elif any(word in user_message for word in ["automation", "automate", "schedule", "routine"]):
        if "create" in user_message or "make" in user_message or "help" in user_message:
            return """🤖 **Automation Assistant**

I can help you create smart automations! Here are some popular examples:

1️⃣ **Time-based Automations**
   • "Turn on lights at sunset"
   • "Turn off everything at 11 PM"
   • "Morning routine at 7 AM"

2️⃣ **Sensor-based Automations**
   • "Turn on lights when motion detected"
   • "Alert if temperature > 25°C"
   • "Turn on AC when room gets hot"

3️⃣ **Energy Saving**
   • "Turn off lights when no motion for 10 mins"
   • "Reduce brightness after 10 PM"
   • "Auto mode for thermostat at night"

What would you like to automate? Just describe it in plain English!"""
        else:
            return """📋 **Current Automations**

You have 3 active automations:

1. **Evening Lights** 🌅
   • Trigger: Sunset
   • Action: Turn on living room lights (60%)
   • Last run: Yesterday, 6:45 PM

2. **Goodnight Routine** 🌙
   • Trigger: 11:00 PM daily
   • Action: Turn off all lights, lock doors
   • Last run: Last night, 11:00 PM

3. **Energy Saver** ⚡
   • Trigger: No motion for 15 minutes
   • Action: Turn off lights in empty rooms
   • Last run: Today, 2:30 PM

Want to create a new automation or modify existing ones?"""
    
    # Energy queries
    elif any(word in user_message for word in ["energy", "consumption", "power", "usage", "kwh", "electricity"]):
        return """⚡ **Energy Consumption Report**

📊 **Today's Overview**
Total Consumption: 2.5 kWh
Estimated Cost: $0.75
Compared to yesterday: -15% (Great job! 👍)

📈 **Top Consumers**
1. Living Room Lights - 0.9 kWh (35%)
2. Thermostat - 0.7 kWh (28%)
3. Bedroom Light - 0.5 kWh (20%)
4. Kitchen Appliances - 0.4 kWh (17%)

💡 **Energy Saving Tips**
• Consider using motion sensors for lights
• Set thermostat to eco mode at night
• Your peak usage is 6-9 PM - try spreading load

🌿 **Carbon Impact**
Saved 2.3 kg CO₂ this week vs. last week!

Would you like weekly reports or automation suggestions to save more energy?"""
    
    # Temperature/Climate queries
    elif any(word in user_message for word in ["temperature", "temp", "hot", "cold", "climate", "thermostat"]):
        return """🌡️ **Climate Status**

**Current Temperature:** 22°C
**Humidity:** 45%
**Target:** 22°C
**Mode:** Auto

**Room-by-Room:**
• Living Room: 22°C (Perfect ✓)
• Bedroom: 21°C (Comfortable ✓)
• Kitchen: 23°C (Slightly warm ⚠️)

**Recommendations:**
• Climate is comfortable in most rooms
• Kitchen is 1°C warmer - consider opening window or adjusting AC

Want me to adjust the thermostat or create a temperature automation?"""
    
    # Light control
    elif any(word in user_message for word in ["light", "lamp", "brightness", "dim"]):
        if any(word in user_message for word in ["turn on", "on", "enable"]):
            return "💡 Turning on the lights now! Set to 80% brightness. Would you like to adjust the brightness level?"
        elif any(word in user_message for word in ["turn off", "off", "disable"]):
            return "💡 Turning off the lights. All lights in the selected area are now off. Anything else I can help with?"
        elif any(word in user_message for word in ["dim", "darker", "lower"]):
            return "💡 Dimming the lights to 40%. Perfect for relaxing! Let me know if you'd like it brighter or darker."
        elif any(word in user_message for word in ["bright", "brighter", "higher"]):
            return "💡 Increasing brightness to 100%. Full brightness activated! Want me to create a 'bright mode' automation?"
        else:
            return """💡 **Lighting Status**

**Currently ON:**
• Living Room Light #1 - 80%
• Living Room Light #2 - 60%

**Currently OFF:**
• Bedroom Light
• Kitchen Light
• Bathroom Light

I can help you:
• Turn lights on/off
• Adjust brightness
• Create lighting schedules
• Set mood lighting scenes

What would you like to do with your lights?"""
    
    # Security/Safety
    elif any(word in user_message for word in ["security", "alarm", "motion", "alert", "safe", "lock"]):
        return """🔒 **Security Status**

**System Status:** ✅ Armed & Secure

**Sensors:**
• Front Door - Closed ✓
• Motion Sensor (Living Room) - No motion ✓
• Window Sensors (3) - All closed ✓

**Recent Activity:**
• 2:45 PM - Motion detected (Living Room)
• 1:30 PM - Front door opened
• 11:00 AM - System armed

**Recommendations:**
• All entry points secured
• Motion sensors active
• Consider adding camera integration

Would you like to enable notifications for security events?"""
    
    # Help/Capabilities
    elif any(word in user_message for word in ["help", "what can", "how to", "capabilities", "features"]):
        return """🤖 **How I Can Help You**

I'm your smart home AI assistant with these capabilities:

📱 **Device Control**
• Check device status
• Turn lights on/off
• Adjust temperature
• Monitor sensors

🤖 **Automation**
• Create smart routines
• Schedule actions
• Sensor-based triggers
• Time-based automations

⚡ **Energy Management**
• Track consumption
• Cost estimates
• Saving recommendations
• Usage analytics

🔒 **Security**
• Monitor sensors
• Get alerts
• Check system status
• Security recommendations

💬 **General**
• Answer questions
• Provide insights
• Give recommendations
• Learn your preferences

Just ask me anything in plain English - I'm here to make your smart home smarter!"""
    
    # Thank you/Positive feedback
    elif any(word in user_message for word in ["thank", "thanks", "great", "awesome", "perfect"]):
        return "You're welcome! 😊 I'm here whenever you need help with your smart home. Is there anything else I can assist you with?"
    
    # Goodbye
    elif any(word in user_message for word in ["bye", "goodbye", "see you", "later"]):
        return "Goodbye! Have a great day! Feel free to come back anytime you need assistance with your smart home. 👋"
    
    # Default response for unknown queries
    else:
        return f"""I received your message: "{msg.message}"

I'm your smart home AI assistant. I can help you with:

• 📱 **Device control** - "What devices are online?"
• 🤖 **Automations** - "Create a sunset automation"
• ⚡ **Energy** - "Show my energy usage"
• 🌡️ **Climate** - "What's the temperature?"
• 💡 **Lighting** - "Turn on living room lights"
• 🔒 **Security** - "Check security status"

What would you like to know about your smart home?"""

# Get chat history endpoint
@app.get("/api/chat/history", response_model=HistoryResponse)
async def get_chat_history(user_id: str):
    """
    Retrieve chat history for a specific user
    
    Args:
        user_id: User identifier
        
    Returns:
        HistoryResponse containing list of messages
    """
    try:
        logger.info(f"Chat history requested for user: {user_id}")
        messages = chat_history.get(user_id, [])
        return HistoryResponse(messages=messages)
    except Exception as e:
        logger.error(f"Error retrieving chat history: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Clear chat history endpoint
@app.delete("/api/chat/history")
async def clear_chat_history(user_id: str):
    """
    Clear chat history for a specific user
    
    Args:
        user_id: User identifier
        
    Returns:
        Status message
    """
    try:
        logger.info(f"Clearing chat history for user: {user_id}")
        if user_id in chat_history:
            chat_history[user_id] = []
        return {"status": "cleared", "user_id": user_id}
    except Exception as e:
        logger.error(f"Error clearing chat history: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Root endpoint
@app.get("/")
async def root():
    """Welcome message"""
    return {
        "message": "Smart Home AI Chat Agent",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "health": "/health",
            "chat": "/api/chat",
            "history": "/api/chat/history",
            "docs": "/docs"
        }
    }

# Run server
if __name__ == "__main__":
    logger.info("Starting Smart Home AI Chat Agent...")
    logger.info("Server will be available at http://0.0.0.0:8000")
    logger.info("API Documentation at http://0.0.0.0:8000/docs")
    
    uvicorn.run(
        app,
        host="0.0.0.0",  # Listen on all network interfaces
        port=8000,
        log_level="info"
    )
