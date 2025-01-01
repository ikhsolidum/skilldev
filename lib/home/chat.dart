import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Message {
  final int id;
  final String content;
  final DateTime timestamp;
  final bool isFromUser;
  final MessageStatus status;
  final int senderId;
  final int? replyTo;

  Message({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isFromUser,
    required this.senderId,
    this.replyTo,
    this.status = MessageStatus.sent,
  });

  factory Message.fromJson(Map<String, dynamic> json, int currentUserId) {
    return Message(
      id: int.parse(json['id'].toString()),
      content: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      isFromUser: int.parse(json['sender_id'].toString()) == currentUserId,
      senderId: int.parse(json['sender_id'].toString()),
      replyTo: json['reply_to'] != null ? int.parse(json['reply_to'].toString()) : null,
      status: MessageStatus.sent,
    );
  }
}

enum MessageStatus { sent, delivered, read }

class ChatPage extends StatefulWidget {
  final String username;
  final String userId;

  const ChatPage({
    Key? key,
    required this.username,
    required this.userId,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isTyping = false;
  bool _isLoading = true;
  int? _lastAdminMessageSenderId;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    Future.delayed(Duration.zero, () {
      _setupMessagePolling();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupMessagePolling() {
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 5));
      if (!mounted) return false;
      await _loadMessages();
      return true;
    });
  }

   Future<void> _loadMessages() async {
    try {
      final response = await http.get(
        Uri.parse('http://bunn.helioho.st/chat.php?user_id=${widget.userId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _messages = (data['messages'] as List)
                .map((msg) => Message.fromJson(
                    msg, int.parse(widget.userId)))
                .toList();
            
            // Find the last admin message sender ID
            for (var i = _messages.length - 1; i >= 0; i--) {
              if (!_messages[i].isFromUser) {
                _lastAdminMessageSenderId = _messages[i].senderId;
                break;
              }
            }
            
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }


  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();
    setState(() => _isTyping = false);

    try {
      final response = await http.post(
        Uri.parse('http://bunn.helioho.st/chat.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sender_id': widget.userId,
          'user_id': widget.userId,
          'message': messageText,
          'reply_to': _lastAdminMessageSenderId, // Add the reply_to field
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success']) {
          await _loadMessages();
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message')),
      );
    }
  }


  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Support',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Typically replies within an hour',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.black87),
            onPressed: () {
              _showSupportInfo(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSupportBanner(),
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? _buildEmptyState()
                : _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildSupportBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Color.fromARGB(255, 110, 227, 192).withOpacity(0.1),
      child: Row(
        children: [
          Icon(
            Icons.support_agent,
            color: Color.fromARGB(255, 110, 227, 192),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Our support team is here to help you with any questions or concerns.',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 110, 227, 192).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: Color.fromARGB(255, 110, 227, 192),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Start a Conversation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Send a message to our admin team and get help with your questions',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color.fromARGB(255, 110, 227, 192),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _MessageBubble(message: message);
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(16).copyWith(
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                onChanged: (value) {
                  setState(() => _isTyping = value.trim().isNotEmpty);
                },
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
              ),
            ),
          ),
          SizedBox(width: 8),
          AnimatedOpacity(
            opacity: _isTyping ? 1.0 : 0.5,
            duration: Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 110, 227, 192),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.send, color: Colors.white),
                onPressed: _isTyping ? _sendMessage : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Support Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.access_time, 'Response Time: Within 1 hour'),
            SizedBox(height: 12),
            _buildInfoRow(Icons.schedule, 'Available: 24/7'),
            SizedBox(height: 12),
            _buildInfoRow(
              Icons.info_outline,
              'For urgent matters, please contact our hotline.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Color.fromARGB(255, 110, 227, 192)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isFromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: message.isFromUser ? 64 : 0,
          right: message.isFromUser ? 0 : 64,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: message.isFromUser
              ? Color.fromARGB(255, 110, 227, 192)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: message.isFromUser ? Radius.circular(0) : null,
            bottomLeft: !message.isFromUser ? Radius.circular(0) : null,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: message.isFromUser ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: message.isFromUser
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                if (message.isFromUser) ...[
                  SizedBox(width: 4),
                  Icon(
                    _getStatusIcon(message.status),
                    size: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  IconData _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
    }
  }
}