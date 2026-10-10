// UMOK Helper: branding and "link to the UMOK account" helpers.
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:url_launcher/url_launcher_string.dart';

const kUmokDisplayName = 'УМОК Помощник';
const kUmokSourceUrl = 'https://github.com/ef1m03/umok-helper';
const _kUmokLinkUrlPrefix = 'https://lk.umokschool.ru/helper/link?id=';
// Local option: the ID for which the link page was already opened automatically.
const _kUmokLinkOpenedOption = 'umok-link-opened-id';

String umokLinkUrl(String id) =>
    '$_kUmokLinkUrlPrefix${Uri.encodeQueryComponent(id)}';

Future<void> umokOpenLink() async {
  final id = (await bind.mainGetMyId()).trim();
  if (id.isEmpty) {
    showToast('ID ещё не получен - подождите несколько секунд');
    return;
  }
  await launchUrlString(umokLinkUrl(id));
}

bool _umokAutoDone = false;

/// Opens the link page once per ID, as soon as the ID is registered on the server.
Future<void> umokAutoOpenLinkOnce(bool online) async {
  if (_umokAutoDone || !online) return;
  final id = (await bind.mainGetMyId()).trim();
  if (id.isEmpty) return;
  _umokAutoDone = true;
  if (bind.mainGetLocalOption(key: _kUmokLinkOpenedOption) == id) return;
  await bind.mainSetLocalOption(key: _kUmokLinkOpenedOption, value: id);
  await launchUrlString(umokLinkUrl(id));
}

Widget buildUmokLinkButton(BuildContext context) {
  return Container(
    margin: const EdgeInsets.only(left: 20, right: 16, top: 4, bottom: 8),
    width: double.infinity,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
      icon: const Icon(Icons.link),
      label: const Text(
        'Привязать к кабинету УМОК',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      onPressed: umokOpenLink,
    ),
  );
}
