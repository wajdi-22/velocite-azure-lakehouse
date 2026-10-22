# Runbook VéloCité

1. Garder une seule exécution du pilote. Vérifier les connexions SQL/ADLS, la présence du CSV météo et le dernier lot dans `vct_ops.RunLog`.
2. En cas d'échec, lire la première activité en erreur dans Monitor et son message. Corriger la cause ; ne pas avancer manuellement le watermark pour masquer l'échec.
3. Relancer le pilote après correction. Contrôler les doublons sur location_id, les métriques et les rejets, puis les deux publications Delta. La validation des watermarks doit être la dernière étape réussie.
4. Pour rejouer sept jours, arrêter la planification et conserver la valeur de watermark initiale. Utiliser une procédure encadrée et journalisée pour abaisser la borne de lecture, rejouer puis restaurer une progression monotone. Ce mode de rejeu est une procédure proposée, pas un bouton de fenêtre déjà livré et testé.
5. Quarantaine : lire entité, clé, cause et payload. Corriger la donnée source, mettre modifie_le à jour et réingérer. Ne pas recopier directement un rejet dans consumption.
6. Vérifier qu'un défaut reste visible dans RunLog et Monitor. Le test `PIPE_90` doit échouer volontairement sans supprimer de données. Vérifier ensuite une alerte Azure Monitor réellement déclenchée.

Recette restante : parcours des JSON paginés, consommation après mapping, doublon/rejeu, correction J-7, anomalie volontaire et effacement RGPD de bout en bout. Le déclencheur est défini à 04h30 Europe/Paris mais arrêté.
