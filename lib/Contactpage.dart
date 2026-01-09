import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactPickerPage extends StatefulWidget {
  const ContactPickerPage({super.key});

  @override
  State<ContactPickerPage> createState() => _ContactPickerPageState();
}

class _ContactPickerPageState extends State<ContactPickerPage> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  Future<void> _loadContacts() async {
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );
    setState(() {
      _contacts = contacts;
      _filteredContacts = contacts;
      _loading = false;
    });
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts
          .where((c) => c.displayName.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Contact"),
        backgroundColor: Colors.white,
        toolbarHeight: 40,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
              Padding(
  padding: const EdgeInsets.all(4.0),
  child: TextField(
    controller: _searchController,
    style: const TextStyle(fontSize: 14),
    decoration: const InputDecoration(
      hintText: "Search contacts...",
      prefixIcon: Icon(Icons.search, size: 18),
      border: OutlineInputBorder(),
      isDense: true, // 👈 compact layout
      contentPadding: EdgeInsets.symmetric(
        vertical: 6,   // 👈 height control
        horizontal: 12,
      ),
    ),
  ),
),

                Expanded(
                  child: _filteredContacts.isEmpty
                      ? const Center(child: Text("No contacts found"))
                      : ListView.builder(
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = _filteredContacts[index];
                            final phone = contact.phones.isNotEmpty
                                ? contact.phones.first.number
                                : "";
                            return ListTile(
                              title: Text(contact.displayName),
                              subtitle: Text(phone),
                              onTap: () {
                                print("phoneee--${phone}");
                                Navigator.pop(context, {
                                  "name": contact.displayName,
                                  "phone": phone,
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
