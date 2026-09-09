import { useState } from "react"
import { router } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"

// Confirm-then-delete for a saved analysis. The dialog stays open while the
// request runs; the redirect to History unmounts it. The confirm label differs
// from the trigger so the two buttons are never ambiguous.
export function DeleteAnalysisDialog({
  url,
  ticker,
  ranAtLabel,
}: {
  url: string
  ticker: string
  ranAtLabel: string
}) {
  const [deleting, setDeleting] = useState(false)

  const destroy = () => {
    router.delete(url, {
      onStart: () => setDeleting(true),
      onFinish: () => setDeleting(false),
    })
  }

  return (
    <Dialog>
      <DialogTrigger asChild>
        <Button variant="ghost">Delete</Button>
      </DialogTrigger>
      <DialogContent size="sm">
        <DialogHeader>
          <DialogTitle>Delete this analysis?</DialogTitle>
          <DialogDescription>
            The {ticker} checklist run on {ranAtLabel} will be removed from History. This cannot be
            undone.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <DialogClose asChild>
            <Button variant="ghost" disabled={deleting}>
              Cancel
            </Button>
          </DialogClose>
          <Button variant="danger" disabled={deleting} onClick={destroy}>
            {deleting ? "Deleting…" : "Delete analysis"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
